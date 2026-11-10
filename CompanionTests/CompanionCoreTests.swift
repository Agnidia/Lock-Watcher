//
//  CompanionCoreTests.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreImage
import os
import XCTest

/// Fails `load` until unlocked, the way a `.completeFileProtection` file does when the app starts on a locked device.
private final class LockableAlertStore: AlertPersisting, @unchecked Sendable {
    private struct State {
        var stored: [ReceivedAlert]
        var isLocked = true
    }

    private let state: OSAllocatedUnfairLock<State>

    init(stored: [ReceivedAlert]) {
        state = OSAllocatedUnfairLock(initialState: State(stored: stored))
    }

    var stored: [ReceivedAlert] {
        state.withLock { $0.stored }
    }

    func unlock() {
        state.withLock { $0.isLocked = false }
    }

    func load() throws -> [ReceivedAlert] {
        try state.withLock { state in
            guard !state.isLocked else { throw CocoaError(.fileReadNoPermission) }
            return state.stored
        }
    }

    func save(_ alerts: [ReceivedAlert]) {
        state.withLock { $0.stored = alerts }
    }
}

@MainActor
final class AlertInboxTests: XCTestCase {
    private func alert(_ id: String, at seconds: TimeInterval) -> ReceivedAlert {
        ReceivedAlert(id: id, title: "Lock-Watcher", body: id, trigger: "onWakeUp", date: Date(timeIntervalSince1970: seconds),
                      latitude: nil, longitude: nil, ip: nil)
    }

    func testIngestDedupesSortsNewestFirstAndPersists() {
        let store = InMemoryAlertStore()
        let sut = AlertInbox(store: store)

        sut.ingest([alert("a", at: 10), alert("b", at: 30)])
        sut.ingest([alert("a", at: 10), alert("c", at: 20)])

        XCTAssertEqual(sut.alerts.map(\.id), ["b", "c", "a"])
        XCTAssertEqual(store.load(), sut.alerts)
    }

    func testCapKeepsNewestAlerts() {
        let sut = AlertInbox(store: InMemoryAlertStore())

        sut.ingest((0 ..< 130).map { alert("\($0)", at: TimeInterval($0)) })

        XCTAssertEqual(sut.alerts.count, AlertInbox.capacity)
        XCTAssertEqual(sut.alerts.first?.id, "129")
        XCTAssertEqual(sut.alerts.last?.id, "30")
    }

    func testLoadsPersistedAlertsOnInit() {
        let sut = AlertInbox(store: InMemoryAlertStore(alerts: [alert("x", at: 1)]))

        XCTAssertEqual(sut.alerts.map(\.id), ["x"])
    }

    func testFailedLoadNeverOverwritesStoredHistory() {
        let history = [alert("h2", at: 20), alert("h1", at: 10)]
        let store = LockableAlertStore(stored: history)
        let sut = AlertInbox(store: store)

        sut.ingest([alert("new", at: 30)])

        XCTAssertEqual(store.stored, history)
        XCTAssertEqual(sut.alerts.map(\.id), ["new"])

        store.unlock()
        sut.ingest([])

        XCTAssertEqual(sut.alerts.map(\.id), ["new", "h2", "h1"])
        XCTAssertEqual(store.stored, sut.alerts)
    }

    func testFileStoreRoundTrip() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FileAlertStore(url: folder.appending(path: "alerts.json"))
        let alerts = [alert("a", at: 5), alert("b", at: 4)]

        store.save(alerts)

        XCTAssertEqual(try store.load(), alerts)
    }

    func testFileStoreReportsNoFileAsEmptyAndAnUnreadableFileAsAnError() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "alerts.json")
        let store = FileAlertStore(url: url)

        XCTAssertEqual(try store.load(), [])

        store.save([alert("a", at: 5)])
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path(percentEncoded: false))

        XCTAssertThrowsError(try store.load())
    }

    func testFileStoreWritesWithCompleteProtection() {
        let protection = FileAlertStore.writeOptions.rawValue & Data.WritingOptions.fileProtectionMask.rawValue

        XCTAssertEqual(protection, Data.WritingOptions.completeFileProtection.rawValue)
        XCTAssertTrue(FileAlertStore.writeOptions.contains(.atomic))
    }

    func testParseReadsSharedPayloadAndFallsBack() throws {
        let payload = PushAlertPayload(trigger: "usbConnected", body: "USB device connected · 14:32", date: Date(timeIntervalSince1970: 1_758_372_720),
                                       latitude: 50.4501, longitude: 30.5234, ip: "203.0.113.7")
        let userInfo = try XCTUnwrap(JSONSerialization.jsonObject(with: payload.encoded()) as? [AnyHashable: Any])

        let parsed = ReceivedAlert.parse(identifier: "id-1", userInfo: userInfo, title: "t", body: "b", deliveredAt: .distantPast)
        let fallback = ReceivedAlert.parse(identifier: "id-2", userInfo: ["aps": ["alert": "plain"]], title: "Title", body: "Body", deliveredAt: .distantPast)

        XCTAssertEqual(parsed.body, "USB device connected · 14:32")
        XCTAssertEqual(parsed.trigger, "usbConnected")
        XCTAssertEqual(parsed.date, Date(timeIntervalSince1970: 1_758_372_720))
        XCTAssertEqual(parsed.latitude, 50.4501)
        XCTAssertEqual(parsed.ip, "203.0.113.7")
        XCTAssertEqual(fallback.title, "Title")
        XCTAssertEqual(fallback.body, "Body")
        XCTAssertNil(fallback.trigger)
        XCTAssertEqual(fallback.date, .distantPast)
    }
}

@MainActor
final class PushRegistrationModelTests: XCTestCase {
    private let configuration = CompanionConfiguration(topic: "com.igrsoft.Lock-Watcher", environment: .sandbox)

    func testDeniedAuthorization() async {
        let sut = PushRegistrationModel(registrar: StubRemoteNotificationRegistrar(isAuthorized: false), configuration: configuration)

        await sut.start()

        XCTAssertEqual(sut.state, .denied)
    }

    func testTokenBecomesPairingCode() async throws {
        let sut = PushRegistrationModel(registrar: StubRemoteNotificationRegistrar(isAuthorized: true), configuration: configuration)

        await sut.start()
        XCTAssertEqual(sut.state, .registering)
        sut.didRegister(deviceToken: Data(repeating: 0xAB, count: 32))

        guard case .ready(let payload) = sut.state else { return XCTFail("expected ready, got \(sut.state)") }
        XCTAssertEqual(payload.token, String(repeating: "ab", count: 32))
        XCTAssertEqual(payload.environment, .sandbox)
        XCTAssertEqual(try PairingPayload.parse(payload.qrString), payload)
    }

    func testShortTokenAndFailureEndInFailed() {
        let sut = PushRegistrationModel(registrar: StubRemoteNotificationRegistrar(isAuthorized: true), configuration: configuration)

        sut.didRegister(deviceToken: Data(count: 8))
        XCTAssertEqual(sut.state, .failed)
        sut.didRegister(deviceToken: Data(repeating: 1, count: 32))
        sut.didFailToRegister()
        XCTAssertEqual(sut.state, .failed)
    }
}

final class QRCodeRendererTests: XCTestCase {
    func testRenderedCodeDecodesBack() throws {
        let text = try PairingPayload(token: String(repeating: "c3", count: 32), environment: .production, topic: "com.igrsoft.Lock-Watcher").qrString

        let image = try XCTUnwrap(QRCodeRenderer.image(for: text))
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: CIImage(cgImage: image)).compactMap { $0 as? CIQRCodeFeature }

        XCTAssertEqual(features?.first?.messageString, text)
    }
}

// MARK: - Source Info

// @source-file: Companion/Core/AlertInbox.swift
// @doc-refs: Companion/Core/PushRegistrationModel.swift, Companion/Core/QRCodeRenderer.swift
