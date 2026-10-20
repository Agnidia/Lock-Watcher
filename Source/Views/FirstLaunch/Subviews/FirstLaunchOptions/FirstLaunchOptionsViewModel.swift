//
//  FirstLaunchOptionsViewModel.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import Observation
import SwiftUI

/// ViewModel for the first launch options configuration.
@Observable
@MainActor
final class FirstLaunchOptionsViewModel {
    /// The application settings.
    /// Ignored by observation as changes are tracked via bindings.
    var settings: AppSettingsProtocol

    private let locationAuthorization: LocationAuthorizationProviding

    init(settings: AppSettingsProtocol, locationAuthorization: LocationAuthorizationProviding = LocationAuthorizationService()) {
        self.settings = settings
        self.locationAuthorization = locationAuthorization
    }

    func requestSnapshotLocationAuthorization(completion: @escaping @MainActor (Bool) -> Void) {
        locationAuthorization.requestAuthorization(completion: completion)
    }

    var isUseSnapshotOnWakeUp: Binding<Bool> {
        Binding<Bool>(
            get: { self.settings.triggers.isUseSnapshotOnWakeUp },
            set: { self.settings.triggers.isUseSnapshotOnWakeUp = $0 }
        )
    }

    var isUseSnapshotOnLogin: Binding<Bool> {
        Binding<Bool>(
            get: { self.settings.triggers.isUseSnapshotOnLogin },
            set: { self.settings.triggers.isUseSnapshotOnLogin = $0 }
        )
    }

    var addLocationToSnapshot: Binding<Bool> {
        Binding<Bool>(
            get: { self.settings.options.addLocationToSnapshot },
            set: { self.settings.options.addLocationToSnapshot = $0 }
        )
    }

    var isICloudSyncEnable: Binding<Bool> {
        Binding<Bool>(
            get: { self.settings.sync.isICloudSyncEnable },
            set: { self.settings.sync.isICloudSyncEnable = $0 }
        )
    }
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/FirstLaunchViewModelTests.swift

extension FirstLaunchOptionsViewModel {
    static var preview: FirstLaunchOptionsViewModel {
        FirstLaunchOptionsViewModel(settings: AppSettingsPreview())
    }
}
