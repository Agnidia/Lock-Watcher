//
//  AlertInbox.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Observation
import os

struct ReceivedAlert: Codable, Sendable, Equatable, Hashable, Identifiable {
    /// The notification request identifier; the dedupe key.
    let id: String
    let title: String
    let body: String
    let trigger: String?
    let date: Date
    let latitude: Double?
    let longitude: Double?
    let ip: String?
    /// Detail-view fields. Optional, so alerts stored before they existed still decode.
    var traceRoute: String?
    var fileName: String?
    var mediaKind: String?
    var host: String?
    var timeZoneID: String?

    init(id: String, title: String, body: String, trigger: String?, date: Date, latitude: Double?, longitude: Double?, ip: String?,
         traceRoute: String? = nil, fileName: String? = nil, mediaKind: String? = nil, host: String? = nil, timeZoneID: String? = nil)
    {
        self.id = id
        self.title = title
        self.body = body
        self.trigger = trigger
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.ip = ip
        self.traceRoute = traceRoute
        self.fileName = fileName
        self.mediaKind = mediaKind
        self.host = host
        self.timeZoneID = timeZoneID
    }

    /// Prefers the shared payload; falls back to the visible notification text when the body is not ours.
    static func parse(identifier: String, userInfo: [AnyHashable: Any], title: String, body: String, deliveredAt: Date) -> ReceivedAlert {
        let payload = decodePayload(userInfo)
        return ReceivedAlert(id: identifier,
                             title: payload?.aps.alert.title ?? title,
                             body: payload?.aps.alert.body ?? body,
                             trigger: payload?.trigger,
                             date: payload.map { Date(timeIntervalSince1970: TimeInterval($0.date)) } ?? deliveredAt,
                             latitude: payload?.lat,
                             longitude: payload?.lon,
                             ip: payload?.ip,
                             traceRoute: payload?.trace,
                             fileName: payload?.file,
                             mediaKind: payload?.media,
                             host: payload?.host,
                             timeZoneID: payload?.tz)
    }

    static func decodePayload(_ userInfo: [AnyHashable: Any]) -> PushAlertPayload? {
        let object = Dictionary(uniqueKeysWithValues: userInfo.compactMap { key, value in (key as? String).map { ($0, value) } })
        guard JSONSerialization.isValidJSONObject(object), let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return try? JSONDecoder().decode(PushAlertPayload.self, from: data)
    }
}

protocol AlertPersisting: Sendable {
    /// Returns an empty list when nothing is stored; throws when stored history exists but cannot be read now.
    func load() throws -> [ReceivedAlert]
    func save(_ alerts: [ReceivedAlert])
}

/// Alerts carry location and IP, so the file is unreadable while the device is locked and written atomically.
///
/// The process can still start while locked (prewarming), so `load` throws rather than report an empty history it could not read.
struct FileAlertStore: AlertPersisting {
    static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtection]

    let url: URL

    static func applicationSupport() -> FileAlertStore {
        FileAlertStore(url: URL.applicationSupportDirectory.appending(path: "Alerts", directoryHint: .isDirectory).appending(path: "alerts.json"))
    }

    func load() throws -> [ReceivedAlert] {
        // Data protection hides file contents, not the directory entry, so a locked file still exists here and then fails the read.
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return [] }
        let data = try Data(contentsOf: url)
        // A file that reads but does not decode cannot be recovered, so the next save may replace it.
        return (try? JSONDecoder().decode([ReceivedAlert].self, from: data)) ?? []
    }

    func save(_ alerts: [ReceivedAlert]) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(alerts).write(to: url, options: Self.writeOptions)
        } catch {
            // The in-memory list stays authoritative; the next ingest writes again.
        }
    }
}

final class InMemoryAlertStore: AlertPersisting, @unchecked Sendable {
    private let state: OSAllocatedUnfairLock<[ReceivedAlert]>

    init(alerts: [ReceivedAlert] = []) {
        state = OSAllocatedUnfairLock(initialState: alerts)
    }

    func load() -> [ReceivedAlert] {
        state.withLock { $0 }
    }

    func save(_ alerts: [ReceivedAlert]) {
        state.withLock { $0 = alerts }
    }
}

/// The single owner of the received-alerts list: deduped by request id, newest first, capped.
///
/// Never saves while stored history is unread, because a list built after a failed load would replace that history on disk.
@MainActor
@Observable
final class AlertInbox {
    /// Stored and shown for Pro; storage never shrinks when Pro lapses, so renewing brings the history back.
    static let capacity = 999
    static let freeVisibleLimit = 3

    private(set) var alerts: [ReceivedAlert]

    @ObservationIgnored private let store: any AlertPersisting
    @ObservationIgnored private var isHistoryUnread: Bool

    init(store: any AlertPersisting) {
        self.store = store
        do {
            alerts = try store.load()
            isHistoryUnread = false
        } catch {
            alerts = []
            isHistoryUnread = true
        }
    }

    func visibleAlerts(isPro: Bool) -> [ReceivedAlert] {
        isPro ? alerts : Array(alerts.prefix(Self.freeVisibleLimit))
    }

    func hiddenCount(isPro: Bool) -> Int {
        alerts.count - visibleAlerts(isPro: isPro).count
    }

    /// Retries unread history first; every activation calls this, so the first one after an unlock merges history before any write.
    func ingest(_ incoming: [ReceivedAlert]) {
        let recovered = reloadHistoryIfUnread()
        let added = merge(incoming)
        guard recovered || added, !isHistoryUnread else { return }
        store.save(alerts)
    }

    /// Returns true when history loaded and alerts received meanwhile were merged into it, so the merged list needs a save.
    private func reloadHistoryIfUnread() -> Bool {
        guard isHistoryUnread, let stored = try? store.load() else { return false }
        isHistoryUnread = false
        let receivedMeanwhile = alerts
        alerts = stored
        return merge(receivedMeanwhile)
    }

    /// Returns true when at least one alert was new.
    private func merge(_ incoming: [ReceivedAlert]) -> Bool {
        var known = Set(alerts.map(\.id))
        let fresh = incoming.filter { known.insert($0.id).inserted }
        guard !fresh.isEmpty else { return false }
        alerts = Array((alerts + fresh).sorted { $0.date > $1.date }.prefix(Self.capacity))
        return true
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
