//
//  AppSettings.swift
//
//  Created on 29.08.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CameraSnap
import Combine
import Foundation
import SwiftUI

/// Defines JPEG compression quality presets for snapshot encoding.
///
/// Raw values represent quality percentage (25–100%).
enum SnapshotQuality: Int, Codable, CaseIterable, Sendable {
    case low = 25
    case medium = 50
    case high = 75
    case original = 100

    /// The compression factor suitable for `NSBitmapImageRep` JPEG encoding (0.0–1.0).
    var compressionFactor: CGFloat {
        CGFloat(rawValue) / 100.0
    }
}

/// Groups the capture preferences: output type, video length, output size and JPEG quality.
///
struct SnapshotSettings: Codable, Equatable {
    /// Video lengths, in seconds, that CameraSnap accepts.
    static let videoDurationRange = 1 ... 5

    /// Photo or video. Default: `.photo`.
    var outputType: CaptureOutputType = .photo

    /// Video length in seconds; valid only inside `videoDurationRange`. Default: 3.
    var videoDuration: Int = 3

    /// Passed unchanged to CameraSnap as both the image and the video size. Default: `.original`.
    var outputSize: CameraSnapConfiguration.OutputSize = .original

    /// JPEG compression quality for photos. Default: `.high` (75%).
    var quality: SnapshotQuality = .high
}

extension SnapshotSettings {
    /// User-approved exception to the no-backward-compatibility rule: v1.5.0 JSON keeps its quality, absent or unreadable fields take defaults, and the legacy `resolution` key is ignored.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SnapshotSettings()
        outputType = (try? container.decodeIfPresent(CaptureOutputType.self, forKey: .outputType)) ?? defaults.outputType
        videoDuration = (try? container.decodeIfPresent(Int.self, forKey: .videoDuration)) ?? defaults.videoDuration
        outputSize = (try? container.decodeIfPresent(CameraSnapConfiguration.OutputSize.self, forKey: .outputSize)) ?? defaults.outputSize
        quality = (try? container.decodeIfPresent(SnapshotQuality.self, forKey: .quality)) ?? defaults.quality
    }
}

/// How long local incident files are kept before the retention pruner deletes them.
///
/// Case order is the picker order, from the longest to the shortest period.
enum RetentionPeriod: String, Codable, CaseIterable, Sendable {
    case oneYear
    case oneMonth
    case oneWeek
    /// Deletes a record's files once every enabled iCloud/Dropbox upload confirms; otherwise the 1-week rule applies.
    case afterUpload

    private static let day: TimeInterval = 24 * 60 * 60

    /// Fixed day counts, so the sweep does not depend on the calendar or the time zone.
    var maxAge: TimeInterval {
        switch self {
        case .oneYear: 365 * Self.day
        case .oneMonth: 30 * Self.day
        case .oneWeek, .afterUpload: 7 * Self.day
        }
    }

    /// The localized picker title.
    var title: String {
        switch self {
        case .oneYear: NSLocalizedString("KeepFilesOneYear", comment: "")
        case .oneMonth: NSLocalizedString("KeepFilesOneMonth", comment: "")
        case .oneWeek: NSLocalizedString("KeepFilesOneWeek", comment: "")
        case .afterUpload: NSLocalizedString("KeepFilesAfterUpload", comment: "")
        }
    }
}

/// Retention preference plus the one-time upgrade state that `RetentionManager` keeps.
///
struct RetentionSettings: Codable, Equatable {
    /// The "Keep files" period. Default: one week.
    var keepFiles: RetentionPeriod = .oneWeek

    /// Set on the first launch of the retention-aware version; older files age from this date, not from their capture date.
    var startDate: Date?

    /// True once the upgrade notice was considered, so it shows at most once.
    var isUpgradeNoticeShown = false

    /// Resets the user's period but keeps the one-time upgrade state, so a reset never re-shows the notice.
    func resettingPreference() -> RetentionSettings {
        RetentionSettings(startDate: startDate, isUpgradeNoticeShown: isUpgradeNoticeShown)
    }
}

/// Represents UI settings to manage and store the state of user interface elements.
///
struct UISettings: Codable, Equatable {
    /// Determines if the security information section is expanded.
    var isSecurityInfoExpand: Bool = true
    
    /// Determines if the snapshot information section is expanded.
    var isSnapshotInfoExpand: Bool = false
    
    /// Determines if the options information section is expanded.
    var isOptionsInfoExpand: Bool = false
    
    /// Determines if the sync information section is expanded.
    var isSyncInfoExpand: Bool = true
}

/// Represents the options/settings related to the application's behavior.
///
struct OptionsSettings: Codable, Equatable {
    /// Indicates whether the application is being launched for the first time.
    var isFirstLaunch: Bool = true
    
    /// The number of last actions to keep track of.
    var keepLastActionsCount: Int = 10
    
    /// Flag to decide if snapshots should be saved to disk.
    var isSaveSnapshotToDisk: Bool = false
    
    /// Determines if the location should be added to snapshots.
    var addLocationToSnapshot: Bool = false
    
    /// Determines if the IP address should be added to snapshots.
    var addIPAddressToSnapshot: Bool = false
    
    /// Determines if a trace route should be added to snapshots.
    var addTraceRouteToSnapshot: Bool = false
    
    /// The server used for trace routing.
    var traceRouteServer: String = ""
    
    /// Flag to indicate if the application settings/data is protected.
    var isProtected: Bool = false
    var authSettings: AuthSettings = .init()
}

struct AuthSettings: Codable, Equatable {
    var biometrics = false
    var watch = false
    var devicePassword = false
    
    static var biometricsOrWatch: Self {
        .init(biometrics: true, watch: true, devicePassword: false)
    }
    
    static var empty: Self {
        .init()
    }
}

/// Represents the triggers for capturing snapshots based on various events.
///
struct TriggerSettings: Codable, Equatable {
    /// Capture a snapshot when the device wakes up.
    var isUseSnapshotOnWakeUp: Bool = true
    
    /// Capture a snapshot upon user login.
    var isUseSnapshotOnLogin: Bool = true
    
    /// Capture a snapshot when a wrong password is entered.
    var isUseSnapshotOnWrongPassword: Bool = false
    
    /// Capture a snapshot when switching to battery power.
    var isUseSnapshotOnSwitchToBatteryPower: Bool = false
    
    /// Capture a snapshot when a USB device is mounted.
    var isUseSnapshotOnUSBMount: Bool = false

    /// Capture a snapshot when a display is attached while the session is locked.
    var isUseSnapshotOnDisplayAttach: Bool = false

    /// Capture a snapshot when the Mac moves while the session is locked.
    var isUseSnapshotOnLocationChange: Bool = false

    /// Capture a snapshot on keyboard or mouse input while the session is locked.
    var isUseSnapshotOnLockedInput: Bool = false

    /// Seconds the session must stay locked after locked input before the snapshot; valid only inside `lockedInputDelayRange`.
    var lockedInputDelay: Int = 10

    static let lockedInputDelayRange = 0 ... 10

    static func clampedLockedInputDelay(_ seconds: Int) -> Int {
        min(max(seconds, lockedInputDelayRange.lowerBound), lockedInputDelayRange.upperBound)
    }
}

extension TriggerSettings {
    /// User-approved exception to the no-backward-compatibility rule: v1.6.0 JSON keeps its five flags, and absent or unreadable keys take defaults.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TriggerSettings()
        isUseSnapshotOnWakeUp = (try? container.decodeIfPresent(Bool.self, forKey: .isUseSnapshotOnWakeUp)) ?? defaults.isUseSnapshotOnWakeUp
        isUseSnapshotOnLogin = (try? container.decodeIfPresent(Bool.self, forKey: .isUseSnapshotOnLogin)) ?? defaults.isUseSnapshotOnLogin
        isUseSnapshotOnWrongPassword = (try? container.decodeIfPresent(Bool.self, forKey: .isUseSnapshotOnWrongPassword)) ?? defaults.isUseSnapshotOnWrongPassword
        isUseSnapshotOnSwitchToBatteryPower = (try? container.decodeIfPresent(Bool.self, forKey: .isUseSnapshotOnSwitchToBatteryPower)) ?? defaults.isUseSnapshotOnSwitchToBatteryPower
        isUseSnapshotOnUSBMount = (try? container.decodeIfPresent(Bool.self, forKey: .isUseSnapshotOnUSBMount)) ?? defaults.isUseSnapshotOnUSBMount
        isUseSnapshotOnDisplayAttach = (try? container.decodeIfPresent(Bool.self, forKey: .isUseSnapshotOnDisplayAttach)) ?? defaults.isUseSnapshotOnDisplayAttach
        isUseSnapshotOnLocationChange = (try? container.decodeIfPresent(Bool.self, forKey: .isUseSnapshotOnLocationChange)) ?? defaults.isUseSnapshotOnLocationChange
        isUseSnapshotOnLockedInput = (try? container.decodeIfPresent(Bool.self, forKey: .isUseSnapshotOnLockedInput)) ?? defaults.isUseSnapshotOnLockedInput
        lockedInputDelay = Self.clampedLockedInputDelay((try? container.decodeIfPresent(Int.self, forKey: .lockedInputDelay)) ?? defaults.lockedInputDelay)
    }
}

/// Represents settings related to synchronization and storage of snapshots.
///
struct SyncSettings: Codable, Equatable {
    /// Determines if snapshots should be saved to disk.
    var isSaveSnapshotToDisk: Bool = false
    
    /// Determines if notifications should be sent to an email.
    var isSendNotificationToMail: Bool = false
    
    /// The email recipient for sending notifications.
    var mailRecipient: String = ""
    
    /// Flag to enable/disable iCloud sync.
    var isICloudSyncEnable: Bool = false
    
    /// Flag to enable/disable Dropbox sync.
    var isDropboxEnable: Bool = false
    
    /// The name of the Dropbox account (or folder).
    var dropboxName: String = ""
    
    /// Determines if a local notification should be used for snapshots.
    var isUseSnapshotLocalNotification: Bool = false
}

/// Protocol that outlines the properties and methods that app settings should conform to.
protocol AppSettingsProtocol {
    /// Flag to indicate if the app is built for Mac App Store.
    static var isMASBuild: Bool { get }
    
    /// Flag to enable/disable image capture debugging.
    static var isImageCaptureDebug: Bool { get }
    
    /// The count of successful launches to determine if it's the app's first launch.
    static var firstLaunchSuccessCount: Int { get }
    
    /// Options/settings related to the application's behavior.
    var options: OptionsSettings { get set }
    
    /// Settings to determine when snapshots should be captured.
    var triggers: TriggerSettings { get set }
    
    /// Settings related to synchronization and storage of snapshots.
    var sync: SyncSettings { get set }

    /// Capture output settings.
    var snapshot: SnapshotSettings { get set }

    /// Local file retention settings.
    var retention: RetentionSettings { get set }

    /// Settings to manage and store the state of user interface elements.
    var ui: UISettings { get set }
    
    /// Resets all settings to their default values.
    func resetToDefaults()
}

/// Class responsible for managing all settings of the application and storing them in UserDefaults.
final class AppSettings: AppSettingsProtocol {
#if NON_MAS_CONFIG
    static let isMASBuild: Bool = false
#else
    static let isMASBuild: Bool = true
#endif
    
    /// Debug flag to check image capturing functionality.
    static let isImageCaptureDebug: Bool = false
    
    /// The default count for successful launches.
    static let firstLaunchSuccessCount = 15
    
    /// Application's behavior settings.
    @UserDefault("OptionsSettings", defaultValue: OptionsSettings())
    var options: OptionsSettings
    
    /// Settings to determine when snapshots should be captured.
    @UserDefault("TriggerSettings", defaultValue: TriggerSettings())
    var triggers: TriggerSettings
    
    /// Settings for syncing and storing snapshots.
    @UserDefault("SyncSettings", defaultValue: SyncSettings())
    var sync: SyncSettings

    /// Capture output settings.
    @UserDefault("SnapshotSettings", defaultValue: SnapshotSettings())
    var snapshot: SnapshotSettings

    /// Local file retention settings; a separate key so older stored groups decode unchanged.
    @UserDefault("RetentionSettings", defaultValue: RetentionSettings())
    var retention: RetentionSettings

    /// UI settings to remember the state of user interface elements.
    @UserDefault("UISettings", defaultValue: UISettings())
    var ui: UISettings
    
    /// Resets all settings to their default values.
    func resetToDefaults() {
        options = OptionsSettings()
        triggers = TriggerSettings()
        sync = SyncSettings()
        snapshot = SnapshotSettings()
        retention = retention.resettingPreference()
        ui = UISettings()
    }
}

/// class for Preview
///
final class AppSettingsPreview: AppSettingsProtocol {
    static let isMASBuild: Bool = true

    static let isImageCaptureDebug: Bool = true

    static let firstLaunchSuccessCount: Int = 15

    var options: OptionsSettings = .init()

    var triggers: TriggerSettings = .init()

    var sync: SyncSettings = .init()

    var snapshot: SnapshotSettings = .init()

    var retention: RetentionSettings = .init()

    var ui: UISettings = .init()

    func resetToDefaults() {
        options = OptionsSettings()
        triggers = TriggerSettings()
        sync = SyncSettings()
        snapshot = SnapshotSettings()
        retention = retention.resettingPreference()
        ui = UISettings()
    }
}

// MARK: - Test Info

// @test-file: Tests/Models/AppSettingsTest.swift
