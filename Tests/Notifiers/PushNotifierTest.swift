//
//  PushNotifierTest.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import CoreLocation
import CryptoKit
import os
import XCTest
@testable import Lock_Watcher

final class PushNotifierTest: XCTestCase {
    private let device = PairedDevice(token: String(repeating: "7c", count: 32), environment: .sandbox, topic: StubAPNsCredentialsProvider.topic, pairedAt: Date())
    private let triggers: [TriggerType] = [.setup, .onWakeUp, .onWrongPassword, .onBatteryPower, .onACPower, .usbConnected, .logedIn,
                                           .displayAttached, .locationChanged, .lockedInput, .debug]

    private struct Harness {
        let sut: PushNotifier
        let transport: MockAPNsTransport
        let store: InMemoryAPNsCredentialStore
        let reachability: MockNetworkReachability
        let outbox: PushOutbox
        let sleeps: SleepRecorder
        let clock: TestClock
    }

    private func makeHarness(replies: [MockAPNsTransport.Reply] = [.init(status: 200, reason: nil)],
                             online: Bool = true,
                             error: URLError? = nil,
                             failures: Int = .max,
                             paired: Bool = true,
                             onSend: (@Sendable () -> Void)? = nil) -> Harness
    {
        let transport = MockAPNsTransport(replies: replies, error: error, failures: failures, onSend: onSend)
        let store = InMemoryAPNsCredentialStore(device: paired ? device : nil)
        let reachability = MockNetworkReachability(isOnline: online)
        let outbox = PushOutbox()
        let sleeps = SleepRecorder()
        let clock = TestClock()
        let client = APNsClient(credentials: StubAPNsCredentialsProvider(privateKey: P256.Signing.PrivateKey()), transport: transport, now: { clock.now })
        let sut = PushNotifier(client: client, store: store, reachability: reachability, outbox: outbox,
                               sleep: { try await sleeps.sleep($0) }, now: { clock.now }, logger: LogMock())
        return Harness(sut: sut, transport: transport, store: store, reachability: reachability, outbox: outbox, sleeps: sleeps, clock: clock)
    }

    private func fullDto(_ trigger: TriggerType = .usbConnected) -> ThiefDto {
        ThiefDto(triggerType: trigger,
                 coordinate: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234),
                 ipAddress: "203.0.113.7",
                 traceRoute: String(repeating: "hop 10.0.0.1 ", count: 1000),
                 snapshot: NSImage(size: NSSize(width: 10, height: 10)),
                 filePath: URL(fileURLWithPath: "/tmp/capture.jpeg"),
                 date: Date(timeIntervalSince1970: 1_758_372_720))
    }

    // MARK: - Payload

    func testWorstCasePayloadHasExactKeysAndFitsAPNsLimit() throws {
        let longest = try XCTUnwrap(triggers.max { $0.name.count < $1.name.count })

        let data = try PushNotifier.payload(for: fullDto(longest))

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let aps = try XCTUnwrap(object["aps"] as? [String: Any])
        let alert = try XCTUnwrap(aps["alert"] as? [String: String])
        XCTAssertLessThanOrEqual(data.count, 4096)
        XCTAssertEqual(Set(object.keys), ["aps", "trigger", "date", "lat", "lon", "ip"])
        XCTAssertEqual(Set(aps.keys), ["alert", "sound", "interruption-level", "thread-id"])
        XCTAssertEqual(alert["title"], "Lock-Watcher")
        XCTAssertEqual(alert["body"]?.hasPrefix(longest.name + " · "), true)
        XCTAssertEqual(aps["sound"] as? String, "default")
        XCTAssertEqual(aps["interruption-level"] as? String, "time-sensitive")
        XCTAssertEqual(aps["thread-id"] as? String, "lockwatcher")
        XCTAssertEqual(object["trigger"] as? String, longest.rawValue)
        XCTAssertEqual(object["date"] as? Int, 1_758_372_720)
        XCTAssertEqual(object["lat"] as? Double, 50.4501)
        XCTAssertEqual(object["lon"] as? Double, 30.5234)
        XCTAssertEqual(object["ip"] as? String, "203.0.113.7")
        XCTAssertEqual(try JSONDecoder().decode(PushAlertPayload.self, from: data).trigger, longest.rawValue)
    }

    func testDisabledLocationAndIPAreOmitted() throws {
        let data = try PushNotifier.payload(for: ThiefDto(triggerType: .onWakeUp))

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["aps", "trigger", "date"])
    }

    func testBodyIsCapped() {
        let payload = PushAlertPayload(trigger: "x", body: String(repeating: "й", count: 500), date: Date(), latitude: nil, longitude: nil, ip: nil)

        XCTAssertEqual(payload.aps.alert.body.count, PushAlertPayload.maxBodyLength)
    }

    // MARK: - Response matrix

    func testSuccessSendsOnceWithOneHourExpiration() async throws {
        let harness = makeHarness()

        try await harness.sut.send(fullDto())

        XCTAssertEqual(harness.transport.requests.count, 1)
        XCTAssertEqual(harness.transport.requests.first?.value(forHTTPHeaderField: "apns-expiration"),
                       String(Int(harness.clock.now.timeIntervalSince1970) + 3600))
    }

    func testBadTokenAndUnregisteredMarkPairingForRepair() async {
        for reply in [MockAPNsTransport.Reply(status: 400, reason: "BadDeviceToken"), .init(status: 410, reason: "Unregistered")] {
            let harness = makeHarness(replies: [reply])

            do {
                try await harness.sut.send(fullDto())
                XCTFail("expected deviceUnregistered for \(reply.status)")
            } catch NotifierError.deviceUnregistered {
            } catch {
                XCTFail("\(error)")
            }

            XCTAssertNil(harness.store.pairedDevice())
            XCTAssertEqual(harness.store.pairingStatus(), .needsRepair)
            XCTAssertEqual(harness.transport.requests.count, 1)
        }
    }

    func testThrottledAndServerErrorsBackOffThenSucceed() async throws {
        for status in [429, 500, 503] {
            let harness = makeHarness(replies: [.init(status: status, reason: "x"), .init(status: status, reason: "x"), .init(status: 200, reason: nil)])

            try await harness.sut.send(fullDto())

            XCTAssertEqual(harness.transport.requests.count, 3, "\(status)")
            XCTAssertEqual(harness.sleeps.calls, [.seconds(1), .seconds(2)], "\(status)")
        }
    }

    func testExhaustedRetriesThrowTransient() async {
        let harness = makeHarness(replies: [.init(status: 503, reason: "ServiceUnavailable")])

        do {
            try await harness.sut.send(fullDto())
            XCTFail("expected uploadFailed")
        } catch NotifierError.uploadFailed(let underlying) {
            XCTAssertEqual(underlying as? APNsError, .transient(503))
        } catch {
            XCTFail("\(error)")
        }
        XCTAssertEqual(harness.transport.requests.count, 3)
        XCTAssertEqual(harness.store.pairedDevice(), device)
    }

    func testOtherRejectionFailsWithoutRetry() async {
        let harness = makeHarness(replies: [.init(status: 400, reason: "BadTopic")])

        do {
            try await harness.sut.send(fullDto())
            XCTFail("expected uploadFailed")
        } catch NotifierError.uploadFailed(let underlying) {
            XCTAssertEqual(underlying as? APNsError, .rejected(400, "BadTopic"))
        } catch {
            XCTFail("\(error)")
        }
        XCTAssertEqual(harness.transport.requests.count, 1)
        XCTAssertTrue(harness.sleeps.calls.isEmpty)
    }

    func testUnpairedThrowsMissingConfiguration() async {
        let harness = makeHarness(paired: false)

        do {
            try await harness.sut.send(fullDto())
            XCTFail("expected missingConfiguration")
        } catch NotifierError.missingConfiguration("push-unpaired") {
        } catch {
            XCTFail("\(error)")
        }
        XCTAssertTrue(harness.transport.requests.isEmpty)
    }

    // MARK: - Offline queue

    func testOfflineAlertIsQueuedThenPostedOnceWhenOnline() async throws {
        let posted = expectation(description: "queued alert posted")
        let harness = makeHarness(online: false, onSend: { posted.fulfill() })

        try await harness.sut.send(fullDto())
        XCTAssertTrue(harness.transport.requests.isEmpty)

        harness.reachability.goOnline()
        await fulfillment(of: [posted], timeout: 2)
        XCTAssertEqual(harness.transport.requests.count, 1)
        let remaining = await harness.outbox.count
        XCTAssertEqual(remaining, 0)
    }

    func testQueuedAlertIsDroppedAfterExpiration() async throws {
        let harness = makeHarness(online: false)

        try await harness.sut.send(fullDto())
        harness.clock.advance(PushNotifier.expirationInterval + 1)
        await harness.sut.drainOutbox()

        XCTAssertTrue(harness.transport.requests.isEmpty)
    }

    func testAlertQueuedWhileOnlineIsRetriedAndPostedOnce() async throws {
        for code in [URLError.Code.timedOut, .cannotFindHost, .notConnectedToInternet] {
            let sends = expectation(description: "failed send, then one post (\(code.rawValue))")
            sends.expectedFulfillmentCount = 2
            let harness = makeHarness(online: true, error: URLError(code), failures: 1, onSend: { sends.fulfill() })

            try await harness.sut.send(fullDto())

            await fulfillment(of: [sends], timeout: 2)
            XCTAssertEqual(harness.transport.requests.count, 2)
            XCTAssertEqual(harness.sleeps.calls, [PushNotifier.onlineRetryDelay])
            let remaining = await harness.outbox.count
            XCTAssertEqual(remaining, 0)
        }
    }

    func testDrainRequeuesAlertThatLosesConnectivityAgain() async throws {
        let sends = expectation(description: "drain fails once, then posts")
        sends.expectedFulfillmentCount = 2
        let harness = makeHarness(online: false, error: URLError(.networkConnectionLost), failures: 1, onSend: { sends.fulfill() })

        try await harness.sut.send(fullDto())
        harness.reachability.goOnline()

        await fulfillment(of: [sends], timeout: 2)
        XCTAssertEqual(harness.transport.requests.count, 2)
        let remaining = await harness.outbox.count
        XCTAssertEqual(remaining, 0)
    }

    func testDrainStopsAtFirstConnectivityLossAndRequeuesTheRestAheadOfANewerAlert() async throws {
        let queued: [TriggerType] = [.onWakeUp, .usbConnected, .logedIn]
        let newer = fullDto(.displayAttached)
        let duringSend = OSAllocatedUnfairLock<(@Sendable () -> Void)?>(initialState: nil)
        let harness = makeHarness(online: false, error: URLError(.timedOut), onSend: { duringSend.withLock { $0 }?() })
        for trigger in queued {
            try await harness.sut.send(fullDto(trigger))
        }
        // The newer alert arrives while the drain waits on its failing send, before the drain re-queues.
        let arrival = OSAllocatedUnfairLock<Task<Void, any Error>?>(initialState: nil)
        duringSend.withLock { [sut = harness.sut, clock = harness.clock] hook in
            hook = {
                clock.advance(60)
                arrival.withLock { $0 = Task { try await sut.send(newer) } }
            }
        }

        await harness.sut.drainOutbox()
        let arrivalSend = try XCTUnwrap(arrival.withLock { $0 })
        try await arrivalSend.value

        XCTAssertEqual(harness.transport.requests.count, 1)
        let requeued = await harness.outbox.drain(now: harness.clock.now)
        let triggers = try requeued.map { try JSONDecoder().decode(PushAlertPayload.self, from: $0.payload).trigger }
        XCTAssertEqual(triggers, (queued + [.displayAttached]).map(\.rawValue))
    }

    func testOutboxInsertsARequeuedBatchAheadOfANewerAlertInOneCall() async {
        let outbox = PushOutbox()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let item = { (tag: UInt8) in PushOutbox.Item(payload: Data([tag]), expiration: start.addingTimeInterval(TimeInterval(tag))) }

        let newerSchedulesDrain = await outbox.enqueue(item(3))
        let batchSchedulesDrain = await outbox.enqueue(contentsOf: [item(0), item(1), item(2)])
        let emptySchedulesDrain = await outbox.enqueue(contentsOf: [PushOutbox.Item]())
        let items = await outbox.drain(now: start)

        XCTAssertTrue(newerSchedulesDrain)
        XCTAssertFalse(batchSchedulesDrain)
        XCTAssertFalse(emptySchedulesDrain)
        XCTAssertEqual(items.map(\.payload), (0 ... 3).map { Data([$0]) })
    }

    func testOutboxDropsOldestPastCapacity() async {
        let outbox = PushOutbox()
        for index in 0 ..< PushOutbox.capacity + 5 {
            _ = await outbox.enqueue(.init(payload: Data([UInt8(index)]), expiration: .distantFuture))
        }

        let items = await outbox.drain(now: Date())

        XCTAssertEqual(items.count, PushOutbox.capacity)
        XCTAssertEqual(items.first?.payload, Data([5]))
    }

    func testLogDescriptionNeverCarriesTheToken() {
        let url = "https://api.push.apple.com/3/device/\(device.token)"
        let urlError = URLError(.timedOut, userInfo: [NSURLErrorFailingURLStringErrorKey: url])

        XCTAssertFalse(PushNotifier.describe(urlError).contains(device.token))
        XCTAssertFalse(PushNotifier.describe(NotifierError.uploadFailed(urlError)).contains(device.token))
    }
}

final class SyncSettingsPushFieldTests: XCTestCase {
    func testPrePushSettingsKeepEveryValue() throws {
        let json = #"{"isSaveSnapshotToDisk":true,"isSendNotificationToMail":true,"mailRecipient":"owner@example.com","isICloudSyncEnable":true,"isDropboxEnable":true,"dropboxName":"Owner","isUseSnapshotLocalNotification":true}"#

        let sync = try JSONDecoder().decode(SyncSettings.self, from: Data(json.utf8))

        XCTAssertEqual(sync.mailRecipient, "owner@example.com")
        XCTAssertEqual(sync.dropboxName, "Owner")
        XCTAssertTrue(sync.isSaveSnapshotToDisk && sync.isSendNotificationToMail && sync.isICloudSyncEnable && sync.isDropboxEnable)
        XCTAssertTrue(sync.isUseSnapshotLocalNotification)
        XCTAssertFalse(sync.isSendPushEnable)
    }

    func testPushFlagRoundTrips() throws {
        var sync = SyncSettings()
        sync.isSendPushEnable = true

        let decoded = try JSONDecoder().decode(SyncSettings.self, from: JSONEncoder().encode(sync))

        XCTAssertEqual(decoded, sync)
    }
}

// MARK: - Source Info

// @source-file: Source/Notifiers/PushNotifier.swift
// @doc-refs: Shared/Push/PushAlertPayload.swift, Source/Models/AppSettings.swift
