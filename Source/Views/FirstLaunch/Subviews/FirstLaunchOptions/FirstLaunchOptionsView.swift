//
//  FirstLaunchOptionsView.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import SwiftUI

@MainActor
struct FirstLaunchOptionsView: View {
    // The view model that provides data and behavior.
    
    @Environment(FirstLaunchOptionsViewModel.self) var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            LaunchAtLoginView()
            UseSnapshotOnWakeUpView(isUseSnapshotOnWakeUp: viewModel.isUseSnapshotOnWakeUp)
            UseSnapshotOnLoginView(isUseSnapshotOnLogin: viewModel.isUseSnapshotOnLogin)
            AddLocationToSnapshotView(addLocationToSnapshot: viewModel.addLocationToSnapshot, requestAuthorization: viewModel.requestSnapshotLocationAuthorization)
            ICloudSyncView(isICloudSyncEnable: viewModel.isICloudSyncEnable)

            Divider()
        }
        .accessibilityIdentifier(AccessibilityID.FirstLaunch.optionsContainer)
    }
}

#Preview("Options View") {
    FirstLaunchOptionsView()
        .environment(FirstLaunchOptionsViewModel.preview)
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/FirstLaunchViewModelTests.swift
