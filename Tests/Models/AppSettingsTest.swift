//
//  AppSettingsTest.swift
//
//  Created on 01.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

// MARK: - UISettings Tests

final class UISettingsTests: XCTestCase {
    func testUISettingsDefaultValues() {
        let settings = UISettings()

        XCTAssertTrue(settings.isSecurityInfoExpand)
        XCTAssertFalse(settings.isSnapshotInfoExpand)
        XCTAssertFalse(settings.isOptionsInfoExpand)
        XCTAssertTrue(settings.isSyncInfoExpand)
    }

    func testUISettingsCustomValues() {
        var settings = UISettings()
        settings.isSecurityInfoExpand = false
        settings.isSnapshotInfoExpand = true
        settings.isOptionsInfoExpand = true
        settings.isSyncInfoExpand = false

        XCTAssertFalse(settings.isSecurityInfoExpand)
        XCTAssertTrue(settings.isSnapshotInfoExpand)
        XCTAssertTrue(settings.isOptionsInfoExpand)
        XCTAssertFalse(settings.isSyncInfoExpand)
    }

    func testUISettingsCodable() throws {
        var original = UISettings()
        original.isSecurityInfoExpand = false
        original.isSnapshotInfoExpand = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UISettings.self, from: data)

        XCTAssertEqual(decoded.isSecurityInfoExpand, original.isSecurityInfoExpand)
        XCTAssertEqual(decoded.isSnapshotInfoExpand, original.isSnapshotInfoExpand)
        XCTAssertEqual(decoded.isOptionsInfoExpand, original.isOptionsInfoExpand)
        XCTAssertEqual(decoded.isSyncInfoExpand, original.isSyncInfoExpand)
    }
}

// MARK: - OptionsSettings Tests

final class OptionsSettingsTests: XCTestCase {
    func testOptionsSettingsDefaultValues() {
        let settings = OptionsSettings()

        XCTAssertTrue(settings.isFirstLaunch)
        XCTAssertEqual(settings.keepLastActionsCount, 10)
        XCTAssertFalse(settings.isSaveSnapshotToDisk)
        XCTAssertFalse(settings.addLocationToSnapshot)
        XCTAssertFalse(settings.addIPAddressToSnapshot)
        XCTAssertFalse(settings.addTraceRouteToSnapshot)
        XCTAssertEqual(settings.traceRouteServer, "")
        XCTAssertFalse(settings.isProtected)
        XCTAssertEqual(settings.authSettings, AuthSettings())
    }

    func testOptionsSettingsCustomValues() {
        var settings = OptionsSettings()
        settings.isFirstLaunch = false
        settings.keepLastActionsCount = 20
        settings.isSaveSnapshotToDisk = true
        settings.addLocationToSnapshot = true
        settings.addIPAddressToSnapshot = true
        settings.addTraceRouteToSnapshot = true
        settings.traceRouteServer = "8.8.8.8"
        settings.isProtected = true

        XCTAssertFalse(settings.isFirstLaunch)
        XCTAssertEqual(settings.keepLastActionsCount, 20)
        XCTAssertTrue(settings.isSaveSnapshotToDisk)
        XCTAssertTrue(settings.addLocationToSnapshot)
        XCTAssertTrue(settings.addIPAddressToSnapshot)
        XCTAssertTrue(settings.addTraceRouteToSnapshot)
        XCTAssertEqual(settings.traceRouteServer, "8.8.8.8")
        XCTAssertTrue(settings.isProtected)
    }

    func testOptionsSettingsCodable() throws {
        var original = OptionsSettings()
        original.isFirstLaunch = false
        original.keepLastActionsCount = 15
        original.traceRouteServer = "google.com"

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OptionsSettings.self, from: data)

        XCTAssertEqual(decoded.isFirstLaunch, original.isFirstLaunch)
        XCTAssertEqual(decoded.keepLastActionsCount, original.keepLastActionsCount)
        XCTAssertEqual(decoded.traceRouteServer, original.traceRouteServer)
    }
}

// MARK: - AuthSettings Tests

final class AuthSettingsTests: XCTestCase {
    func testAuthSettingsDefaultValues() {
        let settings = AuthSettings()

        XCTAssertFalse(settings.biometrics)
        XCTAssertFalse(settings.watch)
        XCTAssertFalse(settings.devicePassword)
    }

    func testAuthSettingsBiometricsOrWatch() {
        let settings = AuthSettings.biometricsOrWatch

        XCTAssertTrue(settings.biometrics)
        XCTAssertTrue(settings.watch)
        XCTAssertFalse(settings.devicePassword)
    }

    func testAuthSettingsEmpty() {
        let settings = AuthSettings.empty

        XCTAssertFalse(settings.biometrics)
        XCTAssertFalse(settings.watch)
        XCTAssertFalse(settings.devicePassword)
    }

    func testAuthSettingsEquatable() {
        let settings1 = AuthSettings(biometrics: true, watch: false, devicePassword: true)
        let settings2 = AuthSettings(biometrics: true, watch: false, devicePassword: true)
        let settings3 = AuthSettings(biometrics: false, watch: true, devicePassword: false)

        XCTAssertEqual(settings1, settings2)
        XCTAssertNotEqual(settings1, settings3)
    }

    func testAuthSettingsCodable() throws {
        let original = AuthSettings(biometrics: true, watch: true, devicePassword: false)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AuthSettings.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}

// MARK: - TriggerSettings Tests

final class TriggerSettingsTests: XCTestCase {
    func testTriggerSettingsDefaultValues() {
        let settings = TriggerSettings()

        XCTAssertTrue(settings.isUseSnapshotOnWakeUp)
        XCTAssertTrue(settings.isUseSnapshotOnLogin)
        XCTAssertFalse(settings.isUseSnapshotOnWrongPassword)
        XCTAssertFalse(settings.isUseSnapshotOnSwitchToBatteryPower)
        XCTAssertFalse(settings.isUseSnapshotOnUSBMount)
    }

    func testTriggerSettingsCustomValues() {
        var settings = TriggerSettings()
        settings.isUseSnapshotOnWakeUp = false
        settings.isUseSnapshotOnLogin = false
        settings.isUseSnapshotOnWrongPassword = true
        settings.isUseSnapshotOnSwitchToBatteryPower = true
        settings.isUseSnapshotOnUSBMount = true

        XCTAssertFalse(settings.isUseSnapshotOnWakeUp)
        XCTAssertFalse(settings.isUseSnapshotOnLogin)
        XCTAssertTrue(settings.isUseSnapshotOnWrongPassword)
        XCTAssertTrue(settings.isUseSnapshotOnSwitchToBatteryPower)
        XCTAssertTrue(settings.isUseSnapshotOnUSBMount)
    }

    func testTriggerSettingsCodable() throws {
        var original = TriggerSettings()
        original.isUseSnapshotOnWakeUp = false
        original.isUseSnapshotOnWrongPassword = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TriggerSettings.self, from: data)

        XCTAssertEqual(decoded.isUseSnapshotOnWakeUp, original.isUseSnapshotOnWakeUp)
        XCTAssertEqual(decoded.isUseSnapshotOnWrongPassword, original.isUseSnapshotOnWrongPassword)
    }

    func testNewTriggerFlagsDefaultOff() {
        let settings = TriggerSettings()

        XCTAssertFalse(settings.isUseSnapshotOnDisplayAttach)
        XCTAssertFalse(settings.isUseSnapshotOnLocationChange)
        XCTAssertFalse(settings.isUseSnapshotOnLockedInput)
    }

    func testStoredV160SettingsKeepTheirFlags() throws {
        let json = #"{"isUseSnapshotOnWakeUp":false,"isUseSnapshotOnLogin":true,"isUseSnapshotOnWrongPassword":true,"isUseSnapshotOnSwitchToBatteryPower":true,"isUseSnapshotOnUSBMount":true}"#

        let decoded = try JSONDecoder().decode(TriggerSettings.self, from: Data(json.utf8))

        XCTAssertFalse(decoded.isUseSnapshotOnWakeUp)
        XCTAssertTrue(decoded.isUseSnapshotOnLogin)
        XCTAssertTrue(decoded.isUseSnapshotOnWrongPassword)
        XCTAssertTrue(decoded.isUseSnapshotOnSwitchToBatteryPower)
        XCTAssertTrue(decoded.isUseSnapshotOnUSBMount)
        XCTAssertFalse(decoded.isUseSnapshotOnDisplayAttach)
        XCTAssertFalse(decoded.isUseSnapshotOnLocationChange)
        XCTAssertFalse(decoded.isUseSnapshotOnLockedInput)
        XCTAssertEqual(decoded.lockedInputDelay, 10)
    }

    func testLockedInputDelayDefaultsToTen() {
        XCTAssertEqual(TriggerSettings().lockedInputDelay, 10)
        XCTAssertEqual(TriggerSettings.lockedInputDelayRange, 0 ... 10)
    }

    func testStoredLockedInputDelayIsClampedIntoRange() throws {
        let high = try JSONDecoder().decode(TriggerSettings.self, from: Data(#"{"lockedInputDelay":42}"#.utf8))
        let low = try JSONDecoder().decode(TriggerSettings.self, from: Data(#"{"lockedInputDelay":-3}"#.utf8))
        let valid = try JSONDecoder().decode(TriggerSettings.self, from: Data(#"{"lockedInputDelay":0}"#.utf8))

        XCTAssertEqual(high.lockedInputDelay, 10)
        XCTAssertEqual(low.lockedInputDelay, 0)
        XCTAssertEqual(valid.lockedInputDelay, 0)
    }

    func testUnreadableTriggerFlagFallsBackAloneToItsDefault() throws {
        let json = #"{"isUseSnapshotOnWakeUp":"yes","isUseSnapshotOnUSBMount":true,"isUseSnapshotOnLockedInput":true}"#

        let decoded = try JSONDecoder().decode(TriggerSettings.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.isUseSnapshotOnWakeUp)
        XCTAssertTrue(decoded.isUseSnapshotOnUSBMount)
        XCTAssertTrue(decoded.isUseSnapshotOnLockedInput)
    }

    func testNewTriggerFlagsRoundTrip() throws {
        var original = TriggerSettings()
        original.isUseSnapshotOnDisplayAttach = true
        original.isUseSnapshotOnLocationChange = true
        original.isUseSnapshotOnLockedInput = true

        let decoded = try JSONDecoder().decode(TriggerSettings.self, from: JSONEncoder().encode(original))

        XCTAssertEqual(decoded, original)
    }
}

// MARK: - SyncSettings Tests

final class SyncSettingsTests: XCTestCase {
    func testSyncSettingsDefaultValues() {
        let settings = SyncSettings()

        XCTAssertFalse(settings.isSaveSnapshotToDisk)
        XCTAssertFalse(settings.isSendNotificationToMail)
        XCTAssertEqual(settings.mailRecipient, "")
        XCTAssertFalse(settings.isICloudSyncEnable)
        XCTAssertFalse(settings.isDropboxEnable)
        XCTAssertEqual(settings.dropboxName, "")
        XCTAssertFalse(settings.isUseSnapshotLocalNotification)
    }

    func testSyncSettingsCustomValues() {
        var settings = SyncSettings()
        settings.isSaveSnapshotToDisk = true
        settings.isSendNotificationToMail = true
        settings.mailRecipient = "test@example.com"
        settings.isICloudSyncEnable = true
        settings.isDropboxEnable = true
        settings.dropboxName = "MyDropbox"
        settings.isUseSnapshotLocalNotification = true

        XCTAssertTrue(settings.isSaveSnapshotToDisk)
        XCTAssertTrue(settings.isSendNotificationToMail)
        XCTAssertEqual(settings.mailRecipient, "test@example.com")
        XCTAssertTrue(settings.isICloudSyncEnable)
        XCTAssertTrue(settings.isDropboxEnable)
        XCTAssertEqual(settings.dropboxName, "MyDropbox")
        XCTAssertTrue(settings.isUseSnapshotLocalNotification)
    }

    func testSyncSettingsCodable() throws {
        var original = SyncSettings()
        original.mailRecipient = "user@domain.com"
        original.dropboxName = "TestFolder"
        original.isICloudSyncEnable = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SyncSettings.self, from: data)

        XCTAssertEqual(decoded.mailRecipient, original.mailRecipient)
        XCTAssertEqual(decoded.dropboxName, original.dropboxName)
        XCTAssertEqual(decoded.isICloudSyncEnable, original.isICloudSyncEnable)
    }
}

// MARK: - SnapshotQuality Tests

final class SnapshotQualityTests: XCTestCase {
    func testCompressionFactors() {
        XCTAssertEqual(SnapshotQuality.low.compressionFactor, 0.25)
        XCTAssertEqual(SnapshotQuality.medium.compressionFactor, 0.50)
        XCTAssertEqual(SnapshotQuality.high.compressionFactor, 0.75)
        XCTAssertEqual(SnapshotQuality.original.compressionFactor, 1.0)
    }

    func testCaseIterable() {
        XCTAssertEqual(SnapshotQuality.allCases.count, 4)
    }

    func testCodable() throws {
        let original = SnapshotQuality.medium
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SnapshotQuality.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - SnapshotSettings Tests

final class SnapshotSettingsTests: XCTestCase {
    func testDefaultValues() {
        let settings = SnapshotSettings()
        XCTAssertEqual(settings.outputType, .photo)
        XCTAssertEqual(settings.videoDuration, 3)
        XCTAssertEqual(settings.outputSize, .original)
        XCTAssertEqual(settings.quality, .high)
    }

    func testCodableRoundTrip() throws {
        var original = SnapshotSettings()
        original.outputType = .video
        original.videoDuration = 5
        original.outputSize = .quarter
        original.quality = .medium

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SnapshotSettings.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testUnreadableFieldFallsBackAloneToItsDefault() throws {
        let json = Data(#"{"outputType":"hologram","videoDuration":4,"outputSize":"1/2","quality":25}"#.utf8)

        let decoded = try JSONDecoder().decode(SnapshotSettings.self, from: json)

        XCTAssertEqual(decoded.outputType, .photo)
        XCTAssertEqual(decoded.videoDuration, 4)
        XCTAssertEqual(decoded.outputSize, .half)
        XCTAssertEqual(decoded.quality, .low)
    }
}

// MARK: - RetentionSettings Tests

final class RetentionSettingsTests: XCTestCase {
    func testDefaultValues() {
        let settings = RetentionSettings()
        XCTAssertEqual(settings.keepFiles, .oneWeek)
        XCTAssertNil(settings.startDate)
        XCTAssertFalse(settings.isUpgradeNoticeShown)
    }

    func testPickerOrderAndMaxAge() {
        let day: TimeInterval = 86_400
        XCTAssertEqual(RetentionPeriod.allCases, [.oneYear, .oneMonth, .oneWeek, .afterUpload])
        XCTAssertEqual(RetentionPeriod.allCases.map(\.maxAge), [365 * day, 30 * day, 7 * day, 7 * day])
    }

    func testResetKeepsUpgradeState() {
        let start = Date(timeIntervalSince1970: 1000)
        let settings = RetentionSettings(keepFiles: .oneYear, startDate: start, isUpgradeNoticeShown: true)

        let reset = settings.resettingPreference()

        XCTAssertEqual(reset, RetentionSettings(keepFiles: .oneWeek, startDate: start, isUpgradeNoticeShown: true))
    }

    func testAppSettingsPreviewResetKeepsRetentionStartDate() {
        let settings = AppSettingsPreview()
        let start = Date(timeIntervalSince1970: 2000)
        settings.retention = RetentionSettings(keepFiles: .oneMonth, startDate: start, isUpgradeNoticeShown: true)

        settings.resetToDefaults()

        XCTAssertEqual(settings.retention.keepFiles, .oneWeek)
        XCTAssertEqual(settings.retention.startDate, start)
    }
}

// MARK: - AppSettingsProtocol Tests

final class AppSettingsProtocolTests: XCTestCase {
    func testAppSettingsStaticProperties() {
        // Test static properties exist and have expected values
        XCTAssertFalse(AppSettings.isImageCaptureDebug)
        XCTAssertEqual(AppSettings.firstLaunchSuccessCount, 15)
        // isMASBuild depends on build configuration
    }

    func testAppSettingsPreviewStaticProperties() {
        XCTAssertTrue(AppSettingsPreview.isMASBuild)
        XCTAssertTrue(AppSettingsPreview.isImageCaptureDebug)
        XCTAssertEqual(AppSettingsPreview.firstLaunchSuccessCount, 15)
    }

    func testAppSettingsPreviewDefaultValues() {
        let settings = AppSettingsPreview()

        // Options
        XCTAssertTrue(settings.options.isFirstLaunch)
        XCTAssertEqual(settings.options.keepLastActionsCount, 10)

        // Triggers
        XCTAssertTrue(settings.triggers.isUseSnapshotOnWakeUp)
        XCTAssertTrue(settings.triggers.isUseSnapshotOnLogin)

        // Sync
        XCTAssertFalse(settings.sync.isICloudSyncEnable)

        // UI
        XCTAssertTrue(settings.ui.isSecurityInfoExpand)
    }

    func testAppSettingsPreviewMutation() {
        let settings = AppSettingsPreview()

        settings.options.isFirstLaunch = false
        settings.triggers.isUseSnapshotOnWakeUp = false
        settings.sync.isICloudSyncEnable = true
        settings.ui.isSecurityInfoExpand = false

        XCTAssertFalse(settings.options.isFirstLaunch)
        XCTAssertFalse(settings.triggers.isUseSnapshotOnWakeUp)
        XCTAssertTrue(settings.sync.isICloudSyncEnable)
        XCTAssertFalse(settings.ui.isSecurityInfoExpand)
    }
}

// MARK: - Source Info

// @source-file: Source/Models/AppSettings.swift
