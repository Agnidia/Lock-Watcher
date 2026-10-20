//
//  InfoViews.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import SwiftUI

/// A SwiftUI view that displays informational controls and links for the application.
struct InfoView: View {
    /// The view model which provides data and functions for the `InfoView`.
    @Environment(InfoViewModel.self) var viewModel: InfoViewModel
    
    /// A binding indicating whether the info section should be extended.
    /// Stored as a Binding reference to maintain two-way data flow with parent.
    @State var isInfoExtended = true
    
    var body: some View {
        let _ = Self.logViewChanges()
        // Main content for the `InfoView`.
        VStack(alignment: .leading) {
            VStack(alignment: .center) {
                // Display debug trigger if `isImageCaptureDebug` is enabled in settings.
                if AppSettings.isImageCaptureDebug {
                    Button(action: viewModel.debugTrigger, label: viewModel.debugTitle)
                        .accessibilityIdentifier(AccessibilityID.Info.debugTriggerButton)

                    // Clean button to reset database and app settings (debug only).
                    Button(action: viewModel.cleanAll, label: viewModel.cleanTitle)
                        .accessibilityIdentifier(AccessibilityID.Info.cleanButton)
                }

                // Button to open the application's settings.
                SettingsLink(label: viewModel.openSettingsTitle)
                    .accessibilityIdentifier(AccessibilityID.Info.openSettingsButton)
                    .accessibilityLabel(AccessibilityLabel.Info.openSettings)
                
                // Button to quit the application.
                Button(action: viewModel.quitApp, label: viewModel.quitAppTitle)
                    .accessibilityIdentifier(AccessibilityID.Info.quitButton)
                    .accessibilityLabel(AccessibilityLabel.Info.quitApp)
                
                // Link to the Agnidia website.
                Link(viewModel.linkText, destination: viewModel.linkUrl)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(AccessibilityID.Info.websiteLink)
                    .accessibilityLabel(AccessibilityLabel.Info.visitWebsite)
            }
            // Extends the view's content based on the `isInfoExtended` property from the view model.
            .extended($isInfoExtended, font: DesignSystem.Typography.title)
        }
        .accessibilityIdentifier(AccessibilityID.Info.container)
    }
}

#Preview("Info Collapsed") {
    InfoView(isInfoExtended: false).environment(InfoViewModel(thiefManager: ThiefManagerPreview()))
}

#Preview("Info Extended") {
    InfoView(isInfoExtended: true).environment(InfoViewModel(thiefManager: ThiefManagerPreview()))
}
