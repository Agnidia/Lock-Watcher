//
//  TriggerManagerTest.swift
//
//  Created on 01.01.2026.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import CoreLocation
import XCTest
@testable import Lock_Watcher

@MainActor
final class TriggerManagerTests: XCTestCase {
    var sut: TriggerManager!
    var mockLogger: LogMock!

    override func setUp() {
        super.setUp()
        mockLogger = LogMock()
        sut = TriggerManager(logger: mockLogger)
    }

    override func tearDown() {
        sut.stop()
        sut = nil
        mockLogger = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testTriggerManagerInit() {
        XCTAssertNotNil(sut)
    }

    // MARK: - Start Tests

    func testStartWithNilSettings() {
        nonisolated(unsafe) var triggerCalled = false

        sut.start(settings: nil) { _ in
            triggerCalled = true
        }

        // With nil settings, no triggers should be enabled
        XCTAssertFalse(triggerCalled)
    }

    func testStartWithPreviewSettings() {
        let settings = AppSettingsPreview()
        nonisolated(unsafe) var triggerCount = 0

        sut.start(settings: settings) { _ in
            triggerCount += 1
        }

        // Verify debug log was called
        XCTAssertNotNil(mockLogger.debugMessage)
        XCTAssertTrue(mockLogger.debugMessage?.contains("Starting") ?? false)
    }

    func testStartWithAllTriggersDisabled() {
        let settings = AppSettingsPreview()
        settings.triggers.isUseSnapshotOnWakeUp = false
        settings.triggers.isUseSnapshotOnLogin = false
        settings.triggers.isUseSnapshotOnWrongPassword = false
        settings.triggers.isUseSnapshotOnSwitchToBatteryPower = false
        settings.triggers.isUseSnapshotOnUSBMount = false

        sut.start(settings: settings) { _ in }

        // Manager should still initialize without crashing
        XCTAssertNotNil(sut)
    }

    func testStartWithWakeUpTriggerEnabled() {
        let settings = AppSettingsPreview()
        settings.triggers.isUseSnapshotOnWakeUp = true
        settings.triggers.isUseSnapshotOnLogin = false

        sut.start(settings: settings) { _ in }

        // Verify the manager started
        XCTAssertNotNil(mockLogger.debugMessage)
    }

    func testStartWithLoginTriggerEnabled() {
        let settings = AppSettingsPreview()
        settings.triggers.isUseSnapshotOnWakeUp = false
        settings.triggers.isUseSnapshotOnLogin = true

        sut.start(settings: settings) { _ in }

        XCTAssertNotNil(mockLogger.debugMessage)
    }

    func testStartWithBatteryPowerTriggerEnabled() {
        let settings = AppSettingsPreview()
        settings.triggers.isUseSnapshotOnWakeUp = false
        settings.triggers.isUseSnapshotOnLogin = false
        settings.triggers.isUseSnapshotOnSwitchToBatteryPower = true

        sut.start(settings: settings) { _ in }

        XCTAssertNotNil(mockLogger.debugMessage)
    }

    func testStartWithUSBMountTriggerEnabled() {
        let settings = AppSettingsPreview()
        settings.triggers.isUseSnapshotOnWakeUp = false
        settings.triggers.isUseSnapshotOnLogin = false
        settings.triggers.isUseSnapshotOnUSBMount = true

        sut.start(settings: settings) { _ in }

        XCTAssertNotNil(mockLogger.debugMessage)
    }

    // MARK: - Stop Tests

    func testStop() {
        let settings = AppSettingsPreview()
        sut.start(settings: settings) { _ in }

        sut.stop()

        // Verify stop was logged
        XCTAssertTrue(mockLogger.debugMessage?.contains("Stop") ?? false)
    }

    func testStopWithoutStart() {
        // Should not crash when stopping without starting
        sut.stop()

        XCTAssertTrue(mockLogger.debugMessage?.contains("Stop") ?? false)
    }

    func testRestartAfterStop() {
        let settings = AppSettingsPreview()

        sut.start(settings: settings) { _ in }
        sut.stop()
        sut.start(settings: settings) { _ in }

        // Should be able to restart after stopping
        XCTAssertNotNil(sut)
    }

    // MARK: - Multiple Starts Tests

    func testMultipleStarts() {
        let settings = AppSettingsPreview()

        sut.start(settings: settings) { _ in }
        sut.start(settings: settings) { _ in }

        // Should handle multiple starts gracefully
        XCTAssertNotNil(sut)
    }

    // MARK: - Protocol Conformance Tests

    func testTriggerManagerConformsToProtocol() {
        let manager: TriggerManagerProtocol = sut

        XCTAssertNotNil(manager)
    }

    // MARK: - Factory Wiring Tests

    /// Builds a manager whose factory hands out `MockListener`s and records every instance per name.
    private func makeFactoryManager() -> (TriggerManager, StubValue<[ListenerName: [MockListener]]>) {
        let made = StubValue<[ListenerName: [MockListener]]>([:])
        let manager = TriggerManager(logger: LogMock(), lockDetector: MockLockDetector(), locationAuthorization: MockLocationAuthorizationService()) { name, _, _ in
            let listener = MockListener()
            made.value[name, default: []].append(listener)
            return listener
        }
        return (manager, made)
    }

    func testNewFlagsStartOnlyTheirListeners() {
        let (manager, made) = makeFactoryManager()
        var triggers = TriggerSettings()
        triggers.isUseSnapshotOnWakeUp = false
        triggers.isUseSnapshotOnLogin = false
        triggers.isUseSnapshotOnDisplayAttach = true
        triggers.isUseSnapshotOnLocationChange = true
        triggers.isUseSnapshotOnLockedInput = true

        manager.start(settings: MockAppSettings(triggers: triggers)) { _ in }

        for name: ListenerName in [.onDisplayListener, .onGeofenceListener, .onLockedInputListener] {
            XCTAssertEqual(made.value[name]?.first?.invokedStartCount, 1, "\(name)")
        }
        for name: ListenerName in [.onWakeUpListener, .onLoginListener, .onUSBConnectionListener, .onBatteryPowerListener] {
            XCTAssertEqual(made.value[name]?.first?.invokedStartCount, 0, "\(name)")
        }
        manager.stop()
    }

    func testDisabledFlagStopsRunningListener() {
        let (manager, made) = makeFactoryManager()
        let settings = MockAppSettings()
        settings.triggers.isUseSnapshotOnDisplayAttach = true
        manager.start(settings: settings) { _ in }

        settings.triggers.isUseSnapshotOnDisplayAttach = false
        manager.start(settings: settings) { _ in }

        let listener = made.value[.onDisplayListener]?.first
        XCTAssertEqual(listener?.invokedStopCount, 1)
        XCTAssertEqual(listener?.isRunning, false)
        manager.stop()
    }

    func testDisabledFlagStopsOpenListenerThatIsNotRunning() {
        let made = StubValue<[ListenerName: [MockListener]]>([:])
        let manager = TriggerManager(logger: LogMock(), lockDetector: MockLockDetector(), locationAuthorization: MockLocationAuthorizationService()) { name, _, _ in
            let listener = MockListener()
            listener.stubbedIsRunningAfterStart = name != .onGeofenceListener
            made.value[name, default: []].append(listener)
            return listener
        }
        let settings = MockAppSettings()
        settings.triggers.isUseSnapshotOnLocationChange = true
        manager.start(settings: settings) { _ in }

        let listener = made.value[.onGeofenceListener]?.first
        XCTAssertEqual(listener?.invokedStartCount, 1)
        XCTAssertEqual(listener?.isRunning, false)

        settings.triggers.isUseSnapshotOnLocationChange = false
        manager.start(settings: settings) { _ in }

        XCTAssertEqual(listener?.invokedStopCount, 1)
        manager.stop()
    }

    func testFactoryCreatesOneListenerPerName() {
        let (manager, made) = makeFactoryManager()
        manager.start(settings: nil) { _ in }

        XCTAssertEqual(Set(made.value.keys), Set(ListenerName.allCases))
        XCTAssertTrue(made.value.values.allSatisfy { $0.count == 1 })
        manager.stop()
    }

    private func makeGeofenceManager(status: CLAuthorizationStatus) -> (TriggerManager, MockLocationAuthorizationService, MockListener) {
        let authorization = MockLocationAuthorizationService(status: status)
        let geofence = MockListener()
        let manager = TriggerManager(logger: LogMock(), lockDetector: MockLockDetector(), locationAuthorization: authorization) { name, _, _ in
            name == .onGeofenceListener ? geofence : MockListener()
        }
        return (manager, authorization, geofence)
    }

    func testPendingGrantStartsGeofenceOnce() {
        let (manager, authorization, geofence) = makeGeofenceManager(status: .notDetermined)
        authorization.requestAuthorization { _ in }
        let settings = MockAppSettings()
        settings.triggers.isUseSnapshotOnLocationChange = true
        manager.start(settings: settings) { _ in }

        XCTAssertTrue(settings.triggers.isUseSnapshotOnLocationChange)
        XCTAssertEqual(geofence.invokedStartCount, 0)

        authorization.send(.authorizedAlways)
        XCTAssertEqual(geofence.invokedStartCount, 1)
        manager.stop()
    }

    func testFirstDenialClearsGeofenceWithoutStarting() {
        let (manager, authorization, geofence) = makeGeofenceManager(status: .notDetermined)
        authorization.requestAuthorization { _ in }
        let settings = MockAppSettings()
        settings.triggers.isUseSnapshotOnLocationChange = true
        manager.start(settings: settings) { _ in }

        authorization.send(.denied)
        XCTAssertFalse(settings.triggers.isUseSnapshotOnLocationChange)
        XCTAssertEqual(geofence.invokedStartCount, 0)
        manager.stop()
    }

    func testRevocationClearsFlagAndStopsGeofence() {
        for status: CLAuthorizationStatus in [.denied, .restricted] {
            let (manager, authorization, geofence) = makeGeofenceManager(status: .authorizedAlways)
            let settings = MockAppSettings()
            settings.triggers.isUseSnapshotOnLocationChange = true
            manager.start(settings: settings) { _ in }
            XCTAssertEqual(geofence.invokedStartCount, 1)

            authorization.send(status)
            XCTAssertFalse(settings.triggers.isUseSnapshotOnLocationChange)
            XCTAssertEqual(geofence.invokedStopCount, 1)

            authorization.send(.authorizedAlways)
            XCTAssertEqual(geofence.invokedStartCount, 1)
            manager.stop()
        }
    }

    func testRelaunchClearsPersistedFlagBeforeListenerStarts() {
        for status: CLAuthorizationStatus in [.denied, .restricted, .notDetermined] {
            let (manager, _, geofence) = makeGeofenceManager(status: status)
            let settings = MockAppSettings()
            settings.triggers.isUseSnapshotOnLocationChange = true
            manager.start(settings: settings) { _ in }
            XCTAssertFalse(settings.triggers.isUseSnapshotOnLocationChange)
            XCTAssertEqual(geofence.invokedStartCount, 0)
            manager.stop()
        }
    }

    func testStoppedManagerDoesNotStartAfterGrant() {
        let (manager, authorization, geofence) = makeGeofenceManager(status: .notDetermined)
        authorization.requestAuthorization { _ in }
        let settings = MockAppSettings()
        settings.triggers.isUseSnapshotOnLocationChange = true
        manager.start(settings: settings) { _ in }
        manager.stop()
        authorization.send(.authorizedAlways)
        XCTAssertEqual(geofence.invokedStartCount, 0)
    }

    func testSnapshotPermissionGrantDoesNotEnableGeofence() {
        let (manager, authorization, geofence) = makeGeofenceManager(status: .notDetermined)
        let settings = MockAppSettings()
        manager.start(settings: settings) { _ in }
        authorization.requestAuthorization { _ in }
        authorization.send(.authorizedAlways)
        XCTAssertFalse(settings.triggers.isUseSnapshotOnLocationChange)
        XCTAssertEqual(geofence.invokedStartCount, 0)
        manager.stop()
    }

    func testYieldTriggersBlockAndRestartsWithFreshListener() async throws {
        let (manager, made) = makeFactoryManager()
        let received = StubValue<[TriggerType]>([])
        let settings = MockAppSettings()
        settings.triggers.isUseSnapshotOnLockedInput = true
        manager.start(settings: settings) { received.value.append($0) }

        made.value[.onLockedInputListener]?.first?.emit((.onLockedInputListener, .lockedInput))
        for _ in 0 ..< 50 where (made.value[.onLockedInputListener]?.count ?? 0) < 2 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(received.value, [.lockedInput])
        XCTAssertEqual(made.value[.onLockedInputListener]?.count, 2)
        XCTAssertEqual(made.value[.onLockedInputListener]?.last?.invokedStartCount, 1)
        manager.stop()
    }

    func testDefaultFactoryBuildsTheNewListeners() {
        let detector = MockLockDetector()
        XCTAssertTrue(TriggerManager.defaultListener(.onDisplayListener, detector, TriggerSettings()) is DisplayListener)
        XCTAssertTrue(TriggerManager.defaultListener(.onLockedInputListener, detector, TriggerSettings()) is LockedInputListener)
        XCTAssertTrue(TriggerManager.defaultListener(.onGeofenceListener, detector, TriggerSettings()) is GeofenceListener)
        XCTAssertEqual(TriggerManager.defaultListener(.onWrongPassword, detector, TriggerSettings()) == nil, AppSettings.isMASBuild)
    }

    // MARK: - Locked Input Delay Tests

    func testDefaultFactoryPassesConfiguredDelay() {
        var triggers = TriggerSettings()
        triggers.lockedInputDelay = 3

        let listener = TriggerManager.defaultListener(.onLockedInputListener, MockLockDetector(), triggers) as? LockedInputListener

        XCTAssertEqual(listener?.grace, 3)
    }

    func testChangedDelayReplacesLockedInputListener() {
        let delays = StubValue<[Int]>([])
        let made = StubValue<[MockListener]>([])
        let manager = TriggerManager(logger: LogMock(), lockDetector: MockLockDetector()) { name, _, triggers in
            let listener = MockListener()
            if name == .onLockedInputListener {
                delays.value.append(triggers.lockedInputDelay)
                made.value.append(listener)
            }
            return listener
        }
        let settings = MockAppSettings()
        settings.triggers.isUseSnapshotOnLockedInput = true
        settings.triggers.lockedInputDelay = 3
        manager.start(settings: settings) { _ in }

        settings.triggers.lockedInputDelay = 7
        manager.start(settings: settings) { _ in }

        XCTAssertEqual(delays.value, [3, 7])
        XCTAssertEqual(made.value.first?.invokedStopCount, 1)
        XCTAssertEqual(made.value.last?.invokedStartCount, 1)
        manager.stop()
    }

    func testLockedInputListenerRearmsThroughTheEventPath() async throws {
        let detector = MockLockDetector()
        let clock = StubValue(Date(timeIntervalSince1970: 1_000_000))
        let idle = StubValue<TimeInterval>(1000)
        let built = StubValue(0)
        let manager = TriggerManager(logger: LogMock(), lockDetector: detector) { name, detector, _ in
            guard name == .onLockedInputListener else { return MockListener() }
            built.value += 1
            return LockedInputListener(logger: LogMock(), lockDetector: detector, secondsSinceInput: { idle.value }, now: { clock.value }, grace: 0, lockStartWindow: 5, rearmCooldown: 30)
        }
        let received = StubValue<[TriggerType]>([])
        let settings = MockAppSettings()
        settings.triggers.isUseSnapshotOnLockedInput = true
        manager.start(settings: settings) { received.value.append($0) }

        func tick(_ locked: Bool, after seconds: TimeInterval = 1) {
            clock.value = clock.value.addingTimeInterval(seconds)
            idle.value += seconds
            detector.tick(locked: locked)
        }

        tick(false)
        tick(true)
        tick(true, after: 6)
        idle.value = 0
        tick(true)
        tick(true)
        for _ in 0 ..< 50 where received.value.isEmpty {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(received.value, [.lockedInput])

        for _ in 0 ..< 31 {
            tick(true)
        }
        idle.value = 0
        tick(true)
        tick(true)
        for _ in 0 ..< 50 where received.value.count < 2 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(received.value, [.lockedInput, .lockedInput])
        XCTAssertEqual(built.value, 1)
        manager.stop()
    }

    func testUnchangedDelayKeepsLockedInputListener() {
        let delays = StubValue<[Int]>([])
        let manager = TriggerManager(logger: LogMock(), lockDetector: MockLockDetector()) { name, _, triggers in
            if name == .onLockedInputListener {
                delays.value.append(triggers.lockedInputDelay)
            }
            return MockListener()
        }
        let settings = MockAppSettings()
        settings.triggers.isUseSnapshotOnLockedInput = true
        manager.start(settings: settings) { _ in }
        manager.start(settings: settings) { _ in }

        XCTAssertEqual(delays.value, [10])
        manager.stop()
    }
}

// MARK: - Mock Settings for Testing

final class MockAppSettings: AppSettingsProtocol {
    static let isMASBuild: Bool = true
    static let isImageCaptureDebug: Bool = false
    static let firstLaunchSuccessCount: Int = 15

    var options: OptionsSettings
    var triggers: TriggerSettings
    var sync: SyncSettings
    var snapshot: SnapshotSettings
    var retention: RetentionSettings
    var ui: UISettings

    init(
        options: OptionsSettings = .init(),
        triggers: TriggerSettings = .init(),
        sync: SyncSettings = .init(),
        snapshot: SnapshotSettings = .init(),
        retention: RetentionSettings = .init(),
        ui: UISettings = .init()
    ) {
        self.options = options
        self.triggers = triggers
        self.sync = sync
        self.snapshot = snapshot
        self.retention = retention
        self.ui = ui
    }

    func resetToDefaults() {
        options = OptionsSettings()
        triggers = TriggerSettings()
        sync = SyncSettings()
        snapshot = SnapshotSettings()
        retention = retention.resettingPreference()
        ui = UISettings()
    }

    static func withAllTriggersEnabled() -> MockAppSettings {
        var triggers = TriggerSettings()
        triggers.isUseSnapshotOnWakeUp = true
        triggers.isUseSnapshotOnLogin = true
        triggers.isUseSnapshotOnWrongPassword = true
        triggers.isUseSnapshotOnSwitchToBatteryPower = true
        triggers.isUseSnapshotOnUSBMount = true
        return MockAppSettings(triggers: triggers)
    }

    static func withNoTriggersEnabled() -> MockAppSettings {
        var triggers = TriggerSettings()
        triggers.isUseSnapshotOnWakeUp = false
        triggers.isUseSnapshotOnLogin = false
        triggers.isUseSnapshotOnWrongPassword = false
        triggers.isUseSnapshotOnSwitchToBatteryPower = false
        triggers.isUseSnapshotOnUSBMount = false
        return MockAppSettings(triggers: triggers)
    }
}

// MARK: - Source Info

// @source-file: Source/Managers/TriggerManager.swift
