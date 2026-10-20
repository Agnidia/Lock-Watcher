//
//  SettingsViewModel.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import CameraSnap
import Combine
import Observation
import SwiftUI

/// ViewModel for handling the settings and configuration of the app.
@Observable
@MainActor
final class SettingsViewModel: DomainViewConstantProtocol {
    // MARK: - DomainViewConstantProtocol

    /// Represents the constants related to the view settings.
    typealias DomainViewConstant = SettingsDomain

    /// Contains the view settings for the domain.
    var viewSettings: SettingsDomain = .init()

    // MARK: - Types

    /// A closure type to handle trigger events.
    typealias SettingsTriggerWatchBlock = Commons.TriggerClosure

    // MARK: - Dependency injection

    /// A manager responsible for handling thief related functionalities.
    @ObservationIgnored
    private var thiefManager: ThiefManagerProtocol

    /// Represents the app's settings.
    private var settings: AppSettingsProtocol

    @ObservationIgnored
    private let locationAuthorization: LocationAuthorizationProviding

    @ObservationIgnored
    private var authorizationObservation: LocationAuthorizationObservation?

    private var authorizationRevision = 0

    // MARK: - Variables

    /// Indicates if the information is hidden or shown.
    var isInfoHidden = true

    /// Indicates if access is granted to some resources.
    var isAccessGranted = true
    
    // Following bindings allow the views to read and modify the underlying settings' values.
    
    // MARK: - Bindings for UI settings
    
    /// Binding for expanding or collapsing security info section.
    var isSecurityInfoExpand: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.ui.isSecurityInfoExpand
        }, set: {
            self.settings.ui.isSecurityInfoExpand = $0
        })
    }
    
    /// Binding for toggling app protection.
    var isProtected: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.options.isProtected
        }, set: {
            self.settings.options.isProtected = $0
        })
    }
    
    var authSettings: Binding<AuthSettings> {
        .init(
            get: { [self] in
                settings.options.authSettings
            },
            set: { [self] in
                settings.options.authSettings = $0
            }
        )
    }
    
    /// Binding for expanding or collapsing snapshot info section.
    var isSnapshotInfoExpand: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.ui.isSnapshotInfoExpand
        }, set: {
            self.settings.ui.isSnapshotInfoExpand = $0
        })
    }
    
    // MARK: - Bindings for Trigger settings
    
    /// Each of these bindings represents a trigger for taking snapshots based on different events.
    var isUseSnapshotOnWakeUp: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.triggers.isUseSnapshotOnWakeUp
        }, set: {
            self.settings.triggers.isUseSnapshotOnWakeUp = $0
        })
    }
    
    var isUseSnapshotOnLogin: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.triggers.isUseSnapshotOnLogin
        }, set: {
            self.settings.triggers.isUseSnapshotOnLogin = $0
        })
    }
    
    var isUseSnapshotOnWrongPassword: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.triggers.isUseSnapshotOnWrongPassword
        }, set: {
            self.settings.triggers.isUseSnapshotOnWrongPassword = $0
        })
    }
    
    var isUseSnapshotOnSwitchToBatteryPower: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.triggers.isUseSnapshotOnSwitchToBatteryPower
        }, set: {
            self.settings.triggers.isUseSnapshotOnSwitchToBatteryPower = $0
        })
    }
    
    var isUseSnapshotOnUSBMount: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.triggers.isUseSnapshotOnUSBMount
        }, set: {
            self.settings.triggers.isUseSnapshotOnUSBMount = $0
        })
    }

    var isUseSnapshotOnDisplayAttach: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.triggers.isUseSnapshotOnDisplayAttach
        }, set: {
            self.settings.triggers.isUseSnapshotOnDisplayAttach = $0
        })
    }

    var isUseSnapshotOnLocationChange: Binding<Bool> {
        Binding<Bool>(get: {
            _ = self.authorizationRevision
            let status = self.locationAuthorization.authorizationStatus
            return self.settings.triggers.isUseSnapshotOnLocationChange
                && (status == .authorizedAlways || (status == .notDetermined && self.locationAuthorization.isRequestPending))
        }, set: {
            guard self.settings.triggers.isUseSnapshotOnLocationChange != $0 else { return }
            self.settings.triggers.isUseSnapshotOnLocationChange = $0
            self.authorizationRevision += 1
            self.updateGeofenceTrigger(enabled: $0)
        })
    }

    var isUseSnapshotOnLockedInput: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.triggers.isUseSnapshotOnLockedInput
        }, set: {
            self.settings.triggers.isUseSnapshotOnLockedInput = $0
        })
    }

    var lockedInputDelay: Binding<Int> {
        Binding<Int>(get: {
            self.settings.triggers.lockedInputDelay
        }, set: {
            self.settings.triggers.lockedInputDelay = TriggerSettings.clampedLockedInputDelay($0)
        })
    }
    
    // MARK: - Bindings for Options settings
    
    /// Binding for expanding or collapsing options info section.
    var isOptionsInfoExpand: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.ui.isOptionsInfoExpand
        }, set: {
            self.settings.ui.isOptionsInfoExpand = $0
        })
    }
    
    /// Number of actions to keep in history.
    var keepLastActionsCount: Binding<Int> {
        Binding<Int>(get: {
            self.settings.options.keepLastActionsCount
        }, set: {
            self.settings.options.keepLastActionsCount = $0
        })
    }
    
    /// Bindings for adding additional information to snapshots.
    var addLocationToSnapshot: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.options.addLocationToSnapshot
        }, set: {
            self.settings.options.addLocationToSnapshot = $0
        })
    }
    
    var addIPAddressToSnapshot: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.options.addIPAddressToSnapshot
        }, set: {
            self.settings.options.addIPAddressToSnapshot = $0
        })
    }
    
    var addTraceRouteToSnapshot: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.options.addTraceRouteToSnapshot
        }, set: {
            self.settings.options.addTraceRouteToSnapshot = $0
        })
    }
    
    /// Server for performing trace route.
    var traceRouteServer: Binding<String> {
        Binding<String>(get: {
            self.settings.options.traceRouteServer
        }, set: {
            self.settings.options.traceRouteServer = $0
        })
    }
    
    // MARK: - Bindings for Sync settings
    
    /// Binding for saving snapshots to disk.
    var isSaveSnapshotToDisk: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.sync.isSaveSnapshotToDisk
        }, set: {
            self.settings.sync.isSaveSnapshotToDisk = $0
        })
    }
    
    /// Binding for expanding or collapsing sync info section.
    var isSyncInfoExpand: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.ui.isSyncInfoExpand
        }, set: {
            self.settings.ui.isSyncInfoExpand = $0
        })
    }
    
    /// Binding for sending notifications to mail.
    var isSendNotificationToMail: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.sync.isSendNotificationToMail
        }, set: {
            self.settings.sync.isSendNotificationToMail = $0
        })
    }
    
    var mailRecipient: Binding<String> {
        Binding<String>(get: {
            self.settings.sync.mailRecipient
        }, set: {
            self.settings.sync.mailRecipient = $0
        })
    }
    
    /// Bindings related to different sync options.
    var isICloudSyncEnable: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.sync.isICloudSyncEnable
        }, set: {
            self.settings.sync.isICloudSyncEnable = $0
        })
    }
    
    var isDropboxEnable: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.sync.isDropboxEnable
        }, set: {
            self.settings.sync.isDropboxEnable = $0
        })
    }
    
    var dropboxName: Binding<String> {
        Binding<String>(get: {
            self.settings.sync.dropboxName
        }, set: {
            self.settings.sync.dropboxName = $0
        })
    }
    
    var isUseSnapshotLocalNotification: Binding<Bool> {
        Binding<Bool>(get: {
            self.settings.sync.isUseSnapshotLocalNotification
        }, set: {
            self.settings.sync.isUseSnapshotLocalNotification = $0
        })
    }

    // MARK: - Bindings for Snapshot settings

    var snapshotQuality: Binding<SnapshotQuality> {
        Binding<SnapshotQuality>(get: {
            self.settings.snapshot.quality
        }, set: {
            self.settings.snapshot.quality = $0
        })
    }

    var snapshotOutputType: Binding<CaptureOutputType> {
        Binding<CaptureOutputType>(get: {
            self.settings.snapshot.outputType
        }, set: {
            self.settings.snapshot.outputType = $0
        })
    }

    var snapshotVideoDuration: Binding<Int> {
        Binding<Int>(get: {
            self.settings.snapshot.videoDuration
        }, set: {
            let range = SnapshotSettings.videoDurationRange
            self.settings.snapshot.videoDuration = min(max($0, range.lowerBound), range.upperBound)
        })
    }

    var snapshotOutputSize: Binding<CameraSnapConfiguration.OutputSize> {
        Binding<CameraSnapConfiguration.OutputSize>(get: {
            self.settings.snapshot.outputSize
        }, set: {
            self.settings.snapshot.outputSize = $0
        })
    }

    var showsVideoDuration: Bool {
        settings.snapshot.outputType == .video
    }

    var showsSnapshotQuality: Bool {
        settings.snapshot.outputType == .photo
    }

    // MARK: - Bindings for Retention settings

    /// A shorter period is held in `pendingKeepFiles` until confirmed, because applying it deletes older files at once.
    var keepFiles: Binding<RetentionPeriod> {
        Binding<RetentionPeriod>(get: {
            self.settings.retention.keepFiles
        }, set: {
            self.requestKeepFiles($0)
        })
    }

    /// A shorter "Keep files" period waiting for the user's confirmation.
    var pendingKeepFiles: RetentionPeriod?

    /// Takes the period the dialog presented, so the alert's own dismissal clearing `pendingKeepFiles` first cannot drop it.
    func confirmKeepFiles(_ period: RetentionPeriod) {
        pendingKeepFiles = nil
        guard period != settings.retention.keepFiles else { return }
        commitKeepFiles(period)
    }

    func cancelPendingKeepFiles() {
        pendingKeepFiles = nil
    }

    private func requestKeepFiles(_ period: RetentionPeriod) {
        let current = settings.retention.keepFiles
        guard period != current else { return }
        let order = RetentionPeriod.allCases
        if let newIndex = order.firstIndex(of: period), let currentIndex = order.firstIndex(of: current), newIndex > currentIndex {
            pendingKeepFiles = period
        } else {
            commitKeepFiles(period)
        }
    }

    private func commitKeepFiles(_ period: RetentionPeriod) {
        settings.retention.keepFiles = period
        thiefManager.applyRetentionPolicy()
    }

    /// Closure to be executed when access is granted.
    /// Ignored by observation as it's a callback infrastructure.
    @ObservationIgnored
    var accessGrantedBlock: Commons.EmptyClosure?
    
    // MARK: - initialiser
    
    /// Initializer for the SettingsViewModel.
    init(settings: AppSettingsProtocol,
         thiefManager: ThiefManagerProtocol,
         locationAuthorization: LocationAuthorizationProviding = LocationAuthorizationService())
    {
        self.settings = settings
        self.thiefManager = thiefManager
        self.locationAuthorization = locationAuthorization

        authorizationObservation = locationAuthorization.observeAuthorization { [weak self] _ in
            self?.authorizationRevision += 1
        }

        watchDropboxUserNameUpdate()
    }

    /// Requests the thief manager to restart watchers based on updated settings.
    func restartWatching() {
        thiefManager.restartWatching()
    }

    /// Asks for location access before the geofence trigger turns on; a refusal turns the flag back off.
    func updateGeofenceTrigger(enabled: Bool) {
        guard enabled else {
            restartWatching()
            return
        }

        locationAuthorization.requestAuthorization { [weak self] isGranted in
            guard let self else { return }
            if !isGranted {
                settings.triggers.isUseSnapshotOnLocationChange = false
                authorizationRevision += 1
            }
            if !isGranted || settings.triggers.isUseSnapshotOnLocationChange {
                restartWatching()
            }
        }
    }

    func requestSnapshotLocationAuthorization(completion: @escaping @MainActor (Bool) -> Void) {
        locationAuthorization.requestAuthorization(completion: completion)
    }

    func refreshLocationAuthorization() {
        locationAuthorization.refreshAuthorization()
    }

    /// Enables or disables the location manager in the thief manager.
    func setupLocationManager(enable: Bool) {
        thiefManager.setupLocationManager(enable: enable)
    }

    /// Observes any updates to the Dropbox user's name and updates the setting accordingly.
    private func watchDropboxUserNameUpdate() {
        Task { [weak self] in
            guard let self else { return }
            for await name in thiefManager.dropboxUserNameUpdates {
                // Already on MainActor, update directly
                settings.sync.dropboxName = name
            }
        }
    }
}

/// Extension to provide preview instance for the SettingsViewModel.
extension SettingsViewModel {
    static var preview: SettingsViewModel {
        SettingsViewModel(settings: AppSettingsPreview(), thiefManager: ThiefManagerPreview())
    }
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/SettingsViewModelTests.swift
