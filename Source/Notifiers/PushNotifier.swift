//
//  PushNotifier.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreLocation
import Foundation

/// Bounded queue of alerts that waited for the network, oldest expiration first.
///
/// In memory only, so no location or IP data rests on disk; an alert queued at quit is lost, and the one-hour expiry bounds that loss.
/// Every item expires a fixed interval after it was created, so expiration order is alert order.
actor PushOutbox {
    struct Item: Sendable {
        let payload: Data
        let expiration: Date
    }

    static let capacity = 20

    private var items: [Item] = []
    private var isDrainScheduled = false

    var count: Int {
        items.count
    }

    /// Drops the oldest item past `capacity`. Returns true when the caller must schedule a drain, so one waiting drain serves every queued alert.
    func enqueue(_ item: Item) -> Bool {
        enqueue(contentsOf: CollectionOfOne(item))
    }

    /// Inserts the whole batch in one actor turn, so an alert that arrives meanwhile cannot land between its items.
    ///
    /// Each item goes after every item that expires no later, which keeps the order of equal expirations and puts
    /// re-queued older alerts ahead of a newer alert that was queued during the drain.
    func enqueue(contentsOf batch: some Collection<Item>) -> Bool {
        guard !batch.isEmpty else { return false }
        for item in batch {
            let index = items.lastIndex { $0.expiration <= item.expiration }.map { $0 + 1 } ?? 0
            items.insert(item, at: index)
        }
        if items.count > Self.capacity {
            items.removeFirst(items.count - Self.capacity)
        }
        defer { isDrainScheduled = true }
        return !isDrainScheduled
    }

    /// Empties the queue and returns the items that have not expired.
    func drain(now: Date) -> [Item] {
        isDrainScheduled = false
        defer { items.removeAll() }
        return items.filter { $0.expiration >= now }
    }
}

/// Sends a time-sensitive alert to the paired iPhone through APNs.
///
/// Sendable without locks: every stored property is immutable and Sendable, and mutable state lives in the `APNsClient` and `PushOutbox` actors.
final class PushNotifier: NotifierProtocol, Sendable {
    /// `apns-expiration` horizon; an alert older than an hour is no longer actionable.
    static let expirationInterval: TimeInterval = 3600
    static let maxAttempts = 3
    /// Waits between attempts; at most 3 s in total, because `NotificationManager` awaits every channel before it reports.
    static let backoff: [Duration] = [.seconds(1), .seconds(2)]
    /// Wait before a queued alert is retried while the path already reports usable, because no online transition will arrive to wake the drain.
    static let onlineRetryDelay: Duration = .seconds(30)

    private let client: APNsClient
    private let store: any APNsCredentialStoring
    private let outbox: PushOutbox
    private let reachability: any NetworkReachability
    private let sleep: @Sendable (Duration) async throws -> Void
    private let now: @Sendable () -> Date
    private let logger: LogProtocol

    init(client: APNsClient,
         store: any APNsCredentialStoring,
         reachability: any NetworkReachability,
         outbox: PushOutbox = PushOutbox(),
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
         now: @escaping @Sendable () -> Date = { Date() },
         logger: LogProtocol = Log(category: .notificationManager))
    {
        self.client = client
        self.store = store
        self.reachability = reachability
        self.outbox = outbox
        self.sleep = sleep
        self.now = now
        self.logger = logger
    }

    /// The production graph; no singletons, so each `NotificationManager` owns its notifier.
    static func live() -> PushNotifier {
        let store = APNsCredentialStore()
        let client = APNsClient(credentials: APNsCredentialsProvider.live(store: store), transport: URLSessionAPNsTransport())
        return PushNotifier(client: client, store: store, reachability: NWPathMonitorReachability())
    }

    func register(with settings: AppSettingsProtocol) {}

    func send(_ thiefDto: ThiefDto) async throws {
        guard let device = store.pairedDevice() else {
            throw NotifierError.missingConfiguration("push-unpaired")
        }
        let item = try PushOutbox.Item(payload: Self.payload(for: thiefDto), expiration: now().addingTimeInterval(Self.expirationInterval))
        guard reachability.isOnline else {
            await queue(CollectionOfOne(item))
            return
        }
        do {
            try await deliver(item, to: device)
        } catch let error as URLError where Self.isConnectivityLoss(error) {
            await queue(CollectionOfOne(item))
        }
    }

    /// Sends every unexpired queued alert through the same retry path as a live send.
    ///
    /// The first connectivity loss sends that alert and every later one back to the queue, so a link that is up while APNs is
    /// unreachable costs one timeout per drain, not one per alert. The expiration filter in `PushOutbox.drain` ends the cycle.
    func drainOutbox() async {
        let items = await outbox.drain(now: now())
        guard !items.isEmpty, let device = store.pairedDevice() else { return }
        for (index, item) in items.enumerated() {
            do {
                try await deliver(item, to: device)
            } catch let error as URLError where Self.isConnectivityLoss(error) {
                await queue(items[index...])
                return
            } catch {
                logger.error("queued push alert failed: \(Self.describe(error))")
            }
        }
    }

    static func payload(for thiefDto: ThiefDto) throws -> Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        let alert = PushAlertPayload(trigger: thiefDto.triggerType.rawValue,
                                     body: "\(thiefDto.triggerType.name) · \(formatter.string(from: thiefDto.date))",
                                     date: thiefDto.date,
                                     latitude: thiefDto.coordinate?.latitude,
                                     longitude: thiefDto.coordinate?.longitude,
                                     ip: thiefDto.ipAddress)
        do {
            return try alert.encoded()
        } catch {
            throw NotifierError.emptyData
        }
    }

    static func isConnectivityLoss(_ error: URLError) -> Bool {
        [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .timedOut, .dataNotAllowed, .internationalRoamingOff]
            .contains(error.code)
    }

    /// A log-safe description: `URLError` text embeds the request URL, and the URL path holds the device token.
    static func describe(_ error: Error) -> String {
        if let error = error as? URLError {
            return "network error \(error.code.rawValue)"
        }
        guard let error = error as? NotifierError else { return "unexpected error" }
        switch error {
        case .uploadFailed(let underlying):
            return (underlying as? APNsError).map { "\($0)" } ?? "uploadFailed"
        case .deviceUnregistered:
            return "deviceUnregistered"
        case .missingConfiguration(let name):
            return "missingConfiguration(\(name))"
        default:
            return "notifierError"
        }
    }

    // MARK: - Private

    /// Response matrix: 200 succeeds; 400 BadDeviceToken / 410 marks the pairing for repair; 429 and 500/503 back off and retry; other codes fail at once.
    private func deliver(_ item: PushOutbox.Item, to device: PairedDevice) async throws {
        for attempt in 1 ... Self.maxAttempts {
            let response = try await client.send(payload: item.payload, to: device, expiration: item.expiration)
            switch response.status {
            case 200:
                return
            case 400 where response.reason == "BadDeviceToken", 410:
                store.markNeedsRepair()
                throw NotifierError.deviceUnregistered
            case 429, 500, 503:
                guard attempt < Self.maxAttempts else {
                    throw NotifierError.uploadFailed(APNsError.transient(response.status))
                }
                try await sleep(Self.backoff[attempt - 1])
            default:
                throw NotifierError.uploadFailed(APNsError.rejected(response.status, response.reason))
            }
        }
    }

    private func queue(_ items: some Collection<PushOutbox.Item> & Sendable) async {
        logger.info("push alert queued until the network returns")
        guard await outbox.enqueue(contentsOf: items) else { return }
        // Subscribe before reading `isOnline`, so a path that turns usable between the two reads is still seen.
        let onlineEvents = reachability.onlineEvents()
        let isOnline = reachability.isOnline
        Task {
            if isOnline {
                // The path is usable but the send failed (APNs blocked, DNS, or the monitor lags after wake): no transition will come.
                try? await self.sleep(Self.onlineRetryDelay)
            } else {
                for await _ in onlineEvents {
                    break
                }
            }
            await self.drainOutbox()
        }
    }
}

// MARK: - Test Info

// @test-file: Tests/Notifiers/PushNotifierTest.swift
// @related-tests: Tests/Managers/NotificationManagerTest.swift
