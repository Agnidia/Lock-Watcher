//
//  SettingsViewModelTests.swift
//
//  Created on 03.01.2026.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import CameraSnap
import Combine
import CoreLocation
import SwiftUI
import XCTest
@testable import Lock_Watcher

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var sut: SettingsViewModel!
    private var mockSettings: AppSettingsPreview!
    private var mockThiefManager: MockThiefManager!
    private var mockAuthorization: MockLocationAuthorizationService!

    override func setUp() async throws {
        try await super.setUp()
        mockSettings = AppSettingsPreview()
        mockThiefManager = MockThiefManager()
        mockThiefManager.stubbedDatabaseManager = MockDatabaseManager()
        mockAuthorization = MockLocationAuthorizationService()
        sut = SettingsViewModel(settings: mockSettings, thiefManager: mockThiefManager, locationAuthorization: mockAuthorization)
    }

    override func tearDown() async throws {
        sut = nil
        mockThiefManager = nil
        mockAuthorization = nil
        mockSettings = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
    }

    func testInitialIsInfoHidden() {
        XCTAssertTrue(sut.isInfoHidden)
    }

    func testInitialIsAccessGranted() {
        XCTAssertTrue(sut.isAccessGranted)
    }

    func testViewSettingsExists() {
        XCTAssertNotNil(sut.viewSettings)
    }

    // MARK: - UI Bindings Tests

    func testIsSecurityInfoExpandBindingReads() {
        mockSettings.ui.isSecurityInfoExpand = true
        XCTAssertTrue(sut.isSecurityInfoExpand.wrappedValue)

        mockSettings.ui.isSecurityInfoExpand = false
        XCTAssertFalse(sut.isSecurityInfoExpand.wrappedValue)
    }

    func testIsSecurityInfoExpandBindingWrites() {
        sut.isSecurityInfoExpand.wrappedValue = false
        XCTAssertFalse(mockSettings.ui.isSecurityInfoExpand)

        sut.isSecurityInfoExpand.wrappedValue = true
        XCTAssertTrue(mockSettings.ui.isSecurityInfoExpand)
    }

    func testIsSnapshotInfoExpandBindingReads() {
        mockSettings.ui.isSnapshotInfoExpand = true
        XCTAssertTrue(sut.isSnapshotInfoExpand.wrappedValue)
    }

    func testIsSnapshotInfoExpandBindingWrites() {
        sut.isSnapshotInfoExpand.wrappedValue = true
        XCTAssertTrue(mockSettings.ui.isSnapshotInfoExpand)
    }

    func testIsOptionsInfoExpandBindingReads() {
        mockSettings.ui.isOptionsInfoExpand = true
        XCTAssertTrue(sut.isOptionsInfoExpand.wrappedValue)
    }

    func testIsOptionsInfoExpandBindingWrites() {
        sut.isOptionsInfoExpand.wrappedValue = true
        XCTAssertTrue(mockSettings.ui.isOptionsInfoExpand)
    }

    func testIsSyncInfoExpandBindingReads() {
        mockSettings.ui.isSyncInfoExpand = true
        XCTAssertTrue(sut.isSyncInfoExpand.wrappedValue)
    }

    func testIsSyncInfoExpandBindingWrites() {
        sut.isSyncInfoExpand.wrappedValue = false
        XCTAssertFalse(mockSettings.ui.isSyncInfoExpand)
    }

    // MARK: - Protection Bindings Tests

    func testIsProtectedBindingReads() {
        mockSettings.options.isProtected = true
        XCTAssertTrue(sut.isProtected.wrappedValue)
    }

    func testIsProtectedBindingWrites() {
        sut.isProtected.wrappedValue = true
        XCTAssertTrue(mockSettings.options.isProtected)
    }

    func testAuthSettingsBindingReads() {
        mockSettings.options.authSettings = .biometricsOrWatch
        XCTAssertEqual(sut.authSettings.wrappedValue, .biometricsOrWatch)
    }

    func testAuthSettingsBindingWrites() {
        sut.authSettings.wrappedValue = .biometricsOrWatch
        XCTAssertEqual(mockSettings.options.authSettings, .biometricsOrWatch)
    }

    // MARK: - Trigger Bindings Tests

    func testIsUseSnapshotOnWakeUpBindingReads() {
        mockSettings.triggers.isUseSnapshotOnWakeUp = true
        XCTAssertTrue(sut.isUseSnapshotOnWakeUp.wrappedValue)
    }

    func testIsUseSnapshotOnWakeUpBindingWrites() {
        sut.isUseSnapshotOnWakeUp.wrappedValue = false
        XCTAssertFalse(mockSettings.triggers.isUseSnapshotOnWakeUp)
    }

    func testIsUseSnapshotOnLoginBindingReads() {
        mockSettings.triggers.isUseSnapshotOnLogin = true
        XCTAssertTrue(sut.isUseSnapshotOnLogin.wrappedValue)
    }

    func testIsUseSnapshotOnLoginBindingWrites() {
        sut.isUseSnapshotOnLogin.wrappedValue = false
        XCTAssertFalse(mockSettings.triggers.isUseSnapshotOnLogin)
    }

    func testIsUseSnapshotOnWrongPasswordBindingReads() {
        mockSettings.triggers.isUseSnapshotOnWrongPassword = true
        XCTAssertTrue(sut.isUseSnapshotOnWrongPassword.wrappedValue)
    }

    func testIsUseSnapshotOnWrongPasswordBindingWrites() {
        sut.isUseSnapshotOnWrongPassword.wrappedValue = true
        XCTAssertTrue(mockSettings.triggers.isUseSnapshotOnWrongPassword)
    }

    func testIsUseSnapshotOnSwitchToBatteryPowerBindingReads() {
        mockSettings.triggers.isUseSnapshotOnSwitchToBatteryPower = true
        XCTAssertTrue(sut.isUseSnapshotOnSwitchToBatteryPower.wrappedValue)
    }

    func testIsUseSnapshotOnSwitchToBatteryPowerBindingWrites() {
        sut.isUseSnapshotOnSwitchToBatteryPower.wrappedValue = true
        XCTAssertTrue(mockSettings.triggers.isUseSnapshotOnSwitchToBatteryPower)
    }

    func testIsUseSnapshotOnUSBMountBindingReads() {
        mockSettings.triggers.isUseSnapshotOnUSBMount = true
        XCTAssertTrue(sut.isUseSnapshotOnUSBMount.wrappedValue)
    }

    func testIsUseSnapshotOnUSBMountBindingWrites() {
        sut.isUseSnapshotOnUSBMount.wrappedValue = true
        XCTAssertTrue(mockSettings.triggers.isUseSnapshotOnUSBMount)
    }

    func testNewTriggerBindingsReadAndWrite() {
        sut.isUseSnapshotOnDisplayAttach.wrappedValue = true
        sut.isUseSnapshotOnLocationChange.wrappedValue = true
        sut.isUseSnapshotOnLockedInput.wrappedValue = true
        XCTAssertTrue(mockSettings.triggers.isUseSnapshotOnDisplayAttach)
        XCTAssertTrue(mockSettings.triggers.isUseSnapshotOnLocationChange)
        XCTAssertTrue(mockSettings.triggers.isUseSnapshotOnLockedInput)

        mockSettings.triggers.isUseSnapshotOnDisplayAttach = false
        mockSettings.triggers.isUseSnapshotOnLocationChange = false
        mockSettings.triggers.isUseSnapshotOnLockedInput = false
        XCTAssertFalse(sut.isUseSnapshotOnDisplayAttach.wrappedValue)
        XCTAssertFalse(sut.isUseSnapshotOnLocationChange.wrappedValue)
        XCTAssertFalse(sut.isUseSnapshotOnLockedInput.wrappedValue)
    }

    func testLockedInputDelayBindingReadsWritesAndClamps() {
        XCTAssertEqual(sut.lockedInputDelay.wrappedValue, 10)

        sut.lockedInputDelay.wrappedValue = 4
        XCTAssertEqual(mockSettings.triggers.lockedInputDelay, 4)

        sut.lockedInputDelay.wrappedValue = 25
        XCTAssertEqual(mockSettings.triggers.lockedInputDelay, 10)

        sut.lockedInputDelay.wrappedValue = -1
        XCTAssertEqual(mockSettings.triggers.lockedInputDelay, 0)

        mockSettings.triggers.lockedInputDelay = 6
        XCTAssertEqual(sut.lockedInputDelay.wrappedValue, 6)
    }

    // MARK: - Geofence Permission Tests

    func testDeniedLocationTurnsGeofenceFlagOff() {
        mockAuthorization.send(.denied)
        sut.isUseSnapshotOnLocationChange.wrappedValue = true
        XCTAssertFalse(mockSettings.triggers.isUseSnapshotOnLocationChange)
        XCTAssertEqual(mockThiefManager.invokedRestartWatchingCount, 1)
        XCTAssertEqual(mockAuthorization.requestCount, 1)
    }

    func testGrantedLocationKeepsGeofenceFlagOn() {
        sut.isUseSnapshotOnLocationChange.wrappedValue = true
        XCTAssertTrue(mockSettings.triggers.isUseSnapshotOnLocationChange)
        XCTAssertEqual(mockThiefManager.invokedRestartWatchingCount, 1)
    }

    func testDisablingGeofenceSkipsPermissionRequest() {
        mockSettings.triggers.isUseSnapshotOnLocationChange = true
        sut.isUseSnapshotOnLocationChange.wrappedValue = false
        XCTAssertEqual(mockAuthorization.requestCount, 0)
        XCTAssertEqual(mockThiefManager.invokedRestartWatchingCount, 1)
    }

    func testDelayedFirstDenialClearsIntentAfterAnswer() {
        mockAuthorization.send(.notDetermined)
        sut.isUseSnapshotOnLocationChange.wrappedValue = true

        XCTAssertTrue(mockSettings.triggers.isUseSnapshotOnLocationChange)
        XCTAssertTrue(sut.isUseSnapshotOnLocationChange.wrappedValue)
        XCTAssertEqual(mockThiefManager.invokedRestartWatchingCount, 0)

        mockAuthorization.send(.denied)

        XCTAssertFalse(mockSettings.triggers.isUseSnapshotOnLocationChange)
        XCTAssertFalse(sut.isUseSnapshotOnLocationChange.wrappedValue)
        XCTAssertEqual(mockThiefManager.invokedRestartWatchingCount, 1)
    }

    func testDelayedFirstGrantKeepsIntentAfterAnswer() {
        mockAuthorization.send(.notDetermined)
        sut.isUseSnapshotOnLocationChange.wrappedValue = true
        XCTAssertEqual(mockThiefManager.invokedRestartWatchingCount, 0)

        mockAuthorization.send(.authorizedAlways)

        XCTAssertTrue(mockSettings.triggers.isUseSnapshotOnLocationChange)
        XCTAssertTrue(sut.isUseSnapshotOnLocationChange.wrappedValue)
        XCTAssertEqual(mockThiefManager.invokedRestartWatchingCount, 1)
    }

    func testTurningOffDuringPromptStaysOffAfterGrant() {
        mockAuthorization.send(.notDetermined)
        sut.isUseSnapshotOnLocationChange.wrappedValue = true
        sut.isUseSnapshotOnLocationChange.wrappedValue = false
        mockAuthorization.send(.authorizedAlways)

        XCTAssertFalse(mockSettings.triggers.isUseSnapshotOnLocationChange)
        XCTAssertEqual(mockThiefManager.invokedRestartWatchingCount, 1)
    }

    func testRevocationImmediatelyShowsGeofenceOff() {
        sut.isUseSnapshotOnLocationChange.wrappedValue = true
        mockAuthorization.send(.restricted)
        XCTAssertFalse(sut.isUseSnapshotOnLocationChange.wrappedValue)
    }

    func testSettingsOpeningRefreshesAuthorization() {
        sut.refreshLocationAuthorization()
        XCTAssertEqual(mockAuthorization.refreshCount, 1)
    }

    func testGeofenceBindingInvalidatesWhenUserChangesIntent() {
        let changed = expectation(description: "geofence binding re-evaluated")
        withObservationTracking {
            _ = sut.isUseSnapshotOnLocationChange.wrappedValue
        } onChange: {
            changed.fulfill()
        }

        sut.isUseSnapshotOnLocationChange.wrappedValue = true

        wait(for: [changed], timeout: 1)
    }

    func testSnapshotRequestReceivesEventualPromptResult() {
        mockAuthorization.send(.notDetermined)
        var result: Bool?
        sut.requestSnapshotLocationAuthorization { result = $0 }
        XCTAssertNil(result)
        mockAuthorization.send(.denied)
        XCTAssertEqual(result, false)
    }

    func testRealServiceCompletesPendingRequestsOnceAfterTerminalStatus() {
        let status = StubValue<CLAuthorizationStatus>(.notDetermined)
        let requests = StubValue(0)
        let service = LocationAuthorizationService(status: { status.value }, request: { requests.value += 1 })
        var results: [Bool] = []

        service.requestAuthorization { results.append($0) }
        service.requestAuthorization { results.append($0) }
        XCTAssertEqual(requests.value, 1)
        XCTAssertTrue(results.isEmpty)

        service.authorizationDidChange()
        XCTAssertTrue(results.isEmpty)

        status.value = .authorizedAlways
        service.authorizationDidChange()
        service.authorizationDidChange()
        XCTAssertEqual(results, [true, true])
    }

    func testRealServiceReportsDenialOnlyAfterAnswer() {
        let status = StubValue<CLAuthorizationStatus>(.notDetermined)
        let service = LocationAuthorizationService(status: { status.value }, request: {})
        var result: Bool?

        service.requestAuthorization { result = $0 }
        service.authorizationDidChange()
        XCTAssertNil(result)

        status.value = .denied
        service.authorizationDidChange()
        XCTAssertEqual(result, false)
    }

    // MARK: - Options Bindings Tests

    func testKeepLastActionsCountBindingReads() {
        mockSettings.options.keepLastActionsCount = 20
        XCTAssertEqual(sut.keepLastActionsCount.wrappedValue, 20)
    }

    func testKeepLastActionsCountBindingWrites() {
        sut.keepLastActionsCount.wrappedValue = 15
        XCTAssertEqual(mockSettings.options.keepLastActionsCount, 15)
    }

    func testAddLocationToSnapshotBindingReads() {
        mockSettings.options.addLocationToSnapshot = true
        XCTAssertTrue(sut.addLocationToSnapshot.wrappedValue)
    }

    func testAddLocationToSnapshotBindingWrites() {
        sut.addLocationToSnapshot.wrappedValue = true
        XCTAssertTrue(mockSettings.options.addLocationToSnapshot)
    }

    func testAddIPAddressToSnapshotBindingReads() {
        mockSettings.options.addIPAddressToSnapshot = true
        XCTAssertTrue(sut.addIPAddressToSnapshot.wrappedValue)
    }

    func testAddIPAddressToSnapshotBindingWrites() {
        sut.addIPAddressToSnapshot.wrappedValue = true
        XCTAssertTrue(mockSettings.options.addIPAddressToSnapshot)
    }

    func testAddTraceRouteToSnapshotBindingReads() {
        mockSettings.options.addTraceRouteToSnapshot = true
        XCTAssertTrue(sut.addTraceRouteToSnapshot.wrappedValue)
    }

    func testAddTraceRouteToSnapshotBindingWrites() {
        sut.addTraceRouteToSnapshot.wrappedValue = true
        XCTAssertTrue(mockSettings.options.addTraceRouteToSnapshot)
    }

    func testTraceRouteServerBindingReads() {
        mockSettings.options.traceRouteServer = "test.server.com"
        XCTAssertEqual(sut.traceRouteServer.wrappedValue, "test.server.com")
    }

    func testTraceRouteServerBindingWrites() {
        sut.traceRouteServer.wrappedValue = "new.server.com"
        XCTAssertEqual(mockSettings.options.traceRouteServer, "new.server.com")
    }

    // MARK: - Sync Bindings Tests

    func testIsSaveSnapshotToDiskBindingReads() {
        mockSettings.sync.isSaveSnapshotToDisk = true
        XCTAssertTrue(sut.isSaveSnapshotToDisk.wrappedValue)
    }

    func testIsSaveSnapshotToDiskBindingWrites() {
        sut.isSaveSnapshotToDisk.wrappedValue = true
        XCTAssertTrue(mockSettings.sync.isSaveSnapshotToDisk)
    }

    func testIsSendNotificationToMailBindingReads() {
        mockSettings.sync.isSendNotificationToMail = true
        XCTAssertTrue(sut.isSendNotificationToMail.wrappedValue)
    }

    func testIsSendNotificationToMailBindingWrites() {
        sut.isSendNotificationToMail.wrappedValue = true
        XCTAssertTrue(mockSettings.sync.isSendNotificationToMail)
    }

    func testMailRecipientBindingReads() {
        mockSettings.sync.mailRecipient = "test@example.com"
        XCTAssertEqual(sut.mailRecipient.wrappedValue, "test@example.com")
    }

    func testMailRecipientBindingWrites() {
        sut.mailRecipient.wrappedValue = "new@example.com"
        XCTAssertEqual(mockSettings.sync.mailRecipient, "new@example.com")
    }

    func testIsICloudSyncEnableBindingReads() {
        mockSettings.sync.isICloudSyncEnable = true
        XCTAssertTrue(sut.isICloudSyncEnable.wrappedValue)
    }

    func testIsICloudSyncEnableBindingWrites() {
        sut.isICloudSyncEnable.wrappedValue = true
        XCTAssertTrue(mockSettings.sync.isICloudSyncEnable)
    }

    func testIsDropboxEnableBindingReads() {
        mockSettings.sync.isDropboxEnable = true
        XCTAssertTrue(sut.isDropboxEnable.wrappedValue)
    }

    func testIsDropboxEnableBindingWrites() {
        sut.isDropboxEnable.wrappedValue = true
        XCTAssertTrue(mockSettings.sync.isDropboxEnable)
    }

    func testDropboxNameBindingReads() {
        mockSettings.sync.dropboxName = "TestUser"
        XCTAssertEqual(sut.dropboxName.wrappedValue, "TestUser")
    }

    func testDropboxNameBindingWrites() {
        sut.dropboxName.wrappedValue = "NewUser"
        XCTAssertEqual(mockSettings.sync.dropboxName, "NewUser")
    }

    func testIsUseSnapshotLocalNotificationBindingReads() {
        mockSettings.sync.isUseSnapshotLocalNotification = true
        XCTAssertTrue(sut.isUseSnapshotLocalNotification.wrappedValue)
    }

    func testIsUseSnapshotLocalNotificationBindingWrites() {
        sut.isUseSnapshotLocalNotification.wrappedValue = true
        XCTAssertTrue(mockSettings.sync.isUseSnapshotLocalNotification)
    }

    // MARK: - Capture Output Binding Tests

    func testOutputTypeBindingAndRowVisibility() {
        XCTAssertEqual(sut.snapshotOutputType.wrappedValue, .photo)
        XCTAssertTrue(sut.showsSnapshotQuality)
        XCTAssertFalse(sut.showsVideoDuration)

        sut.snapshotOutputType.wrappedValue = .video

        XCTAssertEqual(mockSettings.snapshot.outputType, .video)
        XCTAssertTrue(sut.showsVideoDuration)
        XCTAssertFalse(sut.showsSnapshotQuality)
    }

    func testVideoDurationSetterClampsToRange() {
        sut.snapshotVideoDuration.wrappedValue = 4
        XCTAssertEqual(mockSettings.snapshot.videoDuration, 4)

        sut.snapshotVideoDuration.wrappedValue = 9
        XCTAssertEqual(mockSettings.snapshot.videoDuration, 5)

        sut.snapshotVideoDuration.wrappedValue = 0
        XCTAssertEqual(mockSettings.snapshot.videoDuration, 1)
    }

    func testOutputSizeBindingAndPickerLabels() {
        sut.snapshotOutputSize.wrappedValue = .half

        XCTAssertEqual(mockSettings.snapshot.outputSize, .half)
        XCTAssertEqual(CameraSnapConfiguration.OutputSize.allCases.map(\.rawValue), ["Original", "1/2", "1/4"])
    }

    func testOutputTypeChangeIsObserved() {
        let changed = expectation(description: "visibility re-evaluated")
        withObservationTracking {
            _ = sut.showsVideoDuration
        } onChange: {
            changed.fulfill()
        }

        sut.snapshotOutputType.wrappedValue = .video

        wait(for: [changed], timeout: 1)
    }

    // MARK: - Keep Files Binding Tests

    func testLongerPeriodAppliesAtOnce() {
        sut.keepFiles.wrappedValue = .oneMonth

        XCTAssertEqual(mockSettings.retention.keepFiles, .oneMonth)
        XCTAssertNil(sut.pendingKeepFiles)
        XCTAssertEqual(mockThiefManager.invokedApplyRetentionPolicyCount, 1)
    }

    func testUnchangedPeriodDoesNotPrune() {
        sut.keepFiles.wrappedValue = .oneWeek

        XCTAssertEqual(mockThiefManager.invokedApplyRetentionPolicyCount, 0)
    }

    func testShorterPeriodWaitsForConfirmation() {
        sut.keepFiles.wrappedValue = .afterUpload

        XCTAssertEqual(sut.pendingKeepFiles, .afterUpload)
        XCTAssertEqual(mockSettings.retention.keepFiles, .oneWeek)
        XCTAssertEqual(mockThiefManager.invokedApplyRetentionPolicyCount, 0)

        sut.confirmKeepFiles(.afterUpload)

        XCTAssertNil(sut.pendingKeepFiles)
        XCTAssertEqual(mockSettings.retention.keepFiles, .afterUpload)
        XCTAssertEqual(mockThiefManager.invokedApplyRetentionPolicyCount, 1)
    }

    func testConfirmCommitsPresentedPeriodEvenAfterDismissalClearedPending() {
        sut.keepFiles.wrappedValue = .afterUpload
        sut.cancelPendingKeepFiles()

        sut.confirmKeepFiles(.afterUpload)

        XCTAssertEqual(mockSettings.retention.keepFiles, .afterUpload)
        XCTAssertEqual(mockThiefManager.invokedApplyRetentionPolicyCount, 1)
    }

    func testCancelledShorterPeriodKeepsSetting() {
        mockSettings.retention.keepFiles = .oneYear

        sut.keepFiles.wrappedValue = .oneWeek
        sut.cancelPendingKeepFiles()

        XCTAssertNil(sut.pendingKeepFiles)
        XCTAssertEqual(mockSettings.retention.keepFiles, .oneYear)
        XCTAssertEqual(mockThiefManager.invokedApplyRetentionPolicyCount, 0)
    }

    // MARK: - ThiefManager Delegation Tests

    func testRestartWatchingCallsThiefManager() {
        sut.restartWatching()
        XCTAssertTrue(mockThiefManager.invokedRestartWatching)
        XCTAssertEqual(mockThiefManager.invokedRestartWatchingCount, 1)
    }

    func testSetupLocationManagerCallsThiefManager() {
        sut.setupLocationManager(enable: true)
        XCTAssertTrue(mockThiefManager.invokedSetupLocationManager)
        XCTAssertEqual(mockThiefManager.invokedSetupLocationManagerParameters?.enable, true)
    }

    func testSetupLocationManagerWithFalseCallsThiefManager() {
        sut.setupLocationManager(enable: false)
        XCTAssertTrue(mockThiefManager.invokedSetupLocationManager)
        XCTAssertEqual(mockThiefManager.invokedSetupLocationManagerParameters?.enable, false)
    }

    // MARK: - Access Granted Block Tests

    func testAccessGrantedBlockIsInitiallyNil() {
        XCTAssertNil(sut.accessGrantedBlock)
    }

    func testAccessGrantedBlockCanBeSet() {
        var wasCalled = false
        sut.accessGrantedBlock = {
            wasCalled = true
        }

        XCTAssertNotNil(sut.accessGrantedBlock)
        sut.accessGrantedBlock?()
        XCTAssertTrue(wasCalled)
    }

    // MARK: - Preview Tests

    func testPreviewInstanceExists() {
        let preview = SettingsViewModel.preview
        XCTAssertNotNil(preview)
    }

    // MARK: - Dropbox Username Update Tests

    func testDropboxUserNameUpdateChangesSettings() async throws {
        // Emit a new username
        mockThiefManager.emitDropboxUserName("UpdatedUser")

        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        XCTAssertEqual(mockSettings.sync.dropboxName, "UpdatedUser")
    }
}

// MARK: - Source Info

// @source-file: Source/Views/Settings/SettingsViewModel.swift
// @doc-refs: Source/Utils/LocationAuthorizationService.swift
