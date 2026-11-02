//
//  FirstLaunchView.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A view that presents the user with different states during the first launch of the application.
struct FirstLaunchView: View {
    /// The view model injected via environment.
    @Environment(FirstLaunchViewModel.self) var viewModel

    var body: some View {
        let _ = Self.logViewChanges()
        VStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            switch viewModel.state {
            case .idle:
                // Presents options to the user on the first launch.
                FirstLaunchOptionsView()
                    .environment(viewModel.firstLaunchOptionsViewModel)
                
                Button(action: viewModel.takeSnapshot, label: viewModel.takeSnapshotTitle)
                    .alert(viewModel.openSettingsAlertTitle(), isPresented: viewModel.showingAlertBinding) {
                        Button(action: viewModel.openSettings, label: viewModel.openSettingsTitle)
                        Button(role: .cancel, action: {}, label: viewModel.cancelSettingsTitle)
                    }
                    .accessibilityIdentifier(AccessibilityID.FirstLaunch.takeSnapshotButton)
                    .accessibilityLabel(AccessibilityLabel.FirstLaunch.takeSnapshot)
                    .accessibilityHint(AccessibilityHint.FirstLaunch.takeSnapshotHint)
            case .progress:
                // Shows the progress state using a progress view.
                FirstLaunchProgressView()
                    .environment(FirstLaunchProgressViewModel(frameSize: viewModel.safeArea))
                    .accessibilityIdentifier(AccessibilityID.FirstLaunch.progressIndicator)
                    .accessibilityLabel(AccessibilityLabel.FirstLaunch.progress)
            case .success:
                // Displays a success message with a countdown.
                FirstLaunchSuccessView(successCountDown: viewModel.successCountDown, frameSize: viewModel.safeArea)
                    .accessibilityIdentifier(AccessibilityID.FirstLaunch.successView)
                    .accessibilityLabel(AccessibilityLabel.FirstLaunch.success)
            case .fault:
                // Displays an error message. If a restart is needed, it triggers the restart view.
                if !viewModel.isNeedRestart {
                    FirstLaunchFaultViews(isHidden: viewModel.isNeedRestartBinding, frameSize: viewModel.safeArea)
                        .accessibilityIdentifier(AccessibilityID.FirstLaunch.faultView)
                        .accessibilityLabel(AccessibilityLabel.FirstLaunch.fault)
                } else {
                    viewModel.restartView()
                }
            case .anonymous, .authorised:
                // These states do not have associated views.
                EmptyView()
            }
        }
        // Provides padding and a frame for the content.
        .padding(EdgeInsets(top: DesignSystem.Spacing.lg, leading: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.lg, trailing: DesignSystem.Spacing.lg))
        .frame(width: viewModel.viewSettings.window.width, height: viewModel.viewSettings.window.height, alignment: .center)
        .accessibilityIdentifier(AccessibilityID.FirstLaunch.container)
    }
}

#Preview("First Launch") {
    FirstLaunchView()
        .environment(FirstLaunchViewModel.preview)
}
