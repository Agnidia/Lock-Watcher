//
//  CompanionCoreTests.swift
//
//  Created on 11.11.2026.
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

    func testFreeShowsOnlyTheNewestTenAlerts() {
        let sut = AlertInbox(store: InMemoryAlertStore())

        sut.ingest((0 ..< 25).map { alert("\($0)", at: TimeInterval($0)) })

        let visible = sut.visibleAlerts(isPro: false)
        XCTAssertEqual(visible.count, AlertInbox.freeVisibleLimit)
        XCTAssertEqual(visible.first?.id, "24")
        XCTAssertEqual(visible.last?.id, "15")
        XCTAssertEqual(sut.hiddenCount(isPro: false), 15)
    }

    func testProShowsEveryStoredAlert() {
        let sut = AlertInbox(store: InMemoryAlertStore())

        sut.ingest((0 ..< 25).map { alert("\($0)", at: TimeInterval($0)) })

        XCTAssertEqual(sut.visibleAlerts(isPro: true), sut.alerts)
        XCTAssertEqual(sut.hiddenCount(isPro: true), 0)
    }

    func testFreeLimitNeverShrinksStoredHistory() {
        let store = InMemoryAlertStore()
        let sut = AlertInbox(store: store)

        sut.ingest((0 ..< 130).map { alert("\($0)", at: TimeInterval($0)) })
        _ = sut.visibleAlerts(isPro: false)

        XCTAssertEqual(store.load().count, AlertInbox.capacity)
        XCTAssertEqual(sut.hiddenCount(isPro: false), AlertInbox.capacity - AlertInbox.freeVisibleLimit)
    }

    func testFewAlertsHideNothingForFree() {
        let sut = AlertInbox(store: InMemoryAlertStore(alerts: [alert("x", at: 1), alert("y", at: 2)]))

        XCTAssertEqual(sut.visibleAlerts(isPro: false).count, 2)
        XCTAssertEqual(sut.hiddenCount(isPro: false), 0)
    }

    func testYearlySavingsAgainstTwelveMonthlyPayments() {
        XCTAssertEqual(ProPricing.savingsPercent(monthly: 0.99, yearly: 7.99), 33)
    }

    func testNoSavingsWhenYearlyIsNotCheaper() {
        XCTAssertNil(ProPricing.savingsPercent(monthly: 0.99, yearly: 11.88))
        XCTAssertNil(ProPricing.savingsPercent(monthly: 0.99, yearly: 14.99))
    }

    func testSavingsNeedBothPrices() {
        XCTAssertNil(ProPricing.savingsPercent(monthly: 0, yearly: 7.99))
        XCTAssertNil(ProPricing.savingsPercent(monthly: 0.99, yearly: 0))
    }

    func testMonthlyEquivalentOfYearlyPrice() throws {
        let equivalent = try XCTUnwrap(ProPricing.monthlyEquivalent(yearly: 12))
        XCTAssertEqual(equivalent, 1)
        XCTAssertNil(ProPricing.monthlyEquivalent(yearly: 0))
    }

    func testProProductIdsMatchTheAppStoreProducts() {
        XCTAssertEqual(ProProduct.all, [
            "com.igrsoft.LockWatcher.pro.month",
            "com.igrsoft.LockWatcher.pro.year",
            "com.igrsoft.LockWatcher.pro.lifetime"
        ])
    }

    func testEveryMacTriggerHasAnIconAndAName() {
        XCTAssertEqual(AlertTrigger.allCases.count, 11)
        XCTAssertEqual(Set(AlertTrigger.allCases.map(\.symbol)).count, 11)
        XCTAssertEqual(AlertTrigger.usbConnected.titleKey, "AlertTrigger_usbConnected")
    }

    func testUnknownTriggerFallsBack() {
        let missing = ReceivedAlert(id: "m", title: "t", body: "b", trigger: nil, date: .distantPast, latitude: nil, longitude: nil, ip: nil)
        XCTAssertNil(AlertTrigger(alert: missing))
        let future = ReceivedAlert(id: "f", title: "t", body: "b", trigger: "fromANewerMac", date: .distantPast, latitude: nil, longitude: nil, ip: nil)
        XCTAssertNil(AlertTrigger(alert: future))
        let known = ReceivedAlert(id: "k", title: "t", body: "b", trigger: "onWakeUp", date: .distantPast, latitude: nil, longitude: nil, ip: nil)
        XCTAssertEqual(AlertTrigger(alert: known), .onWakeUp)
    }

    func testCoordinatesAndMapsLink() {
        XCTAssertEqual(AlertFormat.coordinates(latitude: 50.45012, longitude: 30.52345), "50.4501, 30.5235")
        XCTAssertEqual(AlertFormat.mapsURL(latitude: 50.4501, longitude: -30.5234)?.absoluteString, "https://maps.apple.com/?ll=50.450100,-30.523400")
    }

    func testShareTextIncludesOnlyWhatTheAlertCarries() {
        let full = ReceivedAlert(id: "x", title: "t", body: "USB device connected · 14:32", trigger: "usbConnected", date: Date(timeIntervalSince1970: 1_758_372_720),
                                 latitude: 50.4501, longitude: 30.5234, ip: "203.0.113.7", host: "MacBook Pro")
        let bare = alert("y", at: 5)

        let fullText = AlertFormat.shareText(for: full)
        let bareText = AlertFormat.shareText(for: bare)

        XCTAssertTrue(fullText.hasPrefix("USB device connected · 14:32\nMacBook Pro\n"))
        XCTAssertTrue(fullText.contains("https://maps.apple.com/?ll=50.450100,30.523400"))
        XCTAssertTrue(fullText.hasSuffix("IP: 203.0.113.7"))
        XCTAssertFalse(bareText.contains("maps.apple.com"))
        XCTAssertFalse(bareText.contains("IP:"))
    }

    func testMacLocalTimeAppearsOnlyWhenTheZonesDiffer() throws {
        let kyiv = try XCTUnwrap(TimeZone(identifier: "Europe/Kyiv"))
        let honolulu = try XCTUnwrap(TimeZone(identifier: "Pacific/Honolulu"))
        let remote = ReceivedAlert(id: "r", title: "t", body: "b", trigger: nil, date: Date(timeIntervalSince1970: 1_758_372_720),
                                   latitude: nil, longitude: nil, ip: nil, timeZoneID: honolulu.identifier)

        XCTAssertNotNil(AlertFormat.macLocalTime(of: remote, phoneZone: kyiv))
        XCTAssertNil(AlertFormat.macLocalTime(of: remote, phoneZone: honolulu))
        XCTAssertNil(AlertFormat.macLocalTime(of: alert("n", at: 1), phoneZone: kyiv))
    }

    func testParseCarriesTheDetailFields() throws {
        let payload = PushAlertPayload(trigger: "usbConnected", body: "b", date: Date(timeIntervalSince1970: 1_758_372_720), latitude: nil, longitude: nil, ip: nil,
                                       trace: "1 10.0.0.1", file: "capture.jpeg", media: PushAlertPayload.photoMedia, host: "MacBook Pro", timeZone: "Europe/Kyiv")
        let userInfo = try XCTUnwrap(JSONSerialization.jsonObject(with: payload.encoded()) as? [AnyHashable: Any])

        let parsed = ReceivedAlert.parse(identifier: "id", userInfo: userInfo, title: "t", body: "b", deliveredAt: .distantPast)

        XCTAssertEqual(parsed.traceRoute, "1 10.0.0.1")
        XCTAssertEqual(parsed.fileName, "capture.jpeg")
        XCTAssertEqual(parsed.mediaKind, "photo")
        XCTAssertEqual(parsed.host, "MacBook Pro")
        XCTAssertEqual(parsed.timeZoneID, "Europe/Kyiv")
    }

    func testAlertStoredBeforeTheDetailFieldsStillDecodes() throws {
        let old = #"[{"id":"a","title":"Lock-Watcher","body":"x","trigger":"onWakeUp","date":770000000,"ip":"203.0.113.7"}]"#

        let alerts = try JSONDecoder().decode([ReceivedAlert].self, from: Data(old.utf8))

        XCTAssertEqual(alerts.first?.ip, "203.0.113.7")
        XCTAssertNil(alerts.first?.traceRoute)
        XCTAssertNil(alerts.first?.fileName)
        XCTAssertNil(alerts.first?.host)
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
