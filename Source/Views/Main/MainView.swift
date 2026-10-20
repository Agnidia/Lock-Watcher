//
//  MainView.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A SwiftUI view that represents the main content of the application.
struct MainView: View {
    /// The view model injected via environment.
    @Environment(MainViewModel.self) var viewModel

    /// The body content of the `MainView`.
    var body: some View {
        let _ = Self.logViewChanges()
        // If access is granted, show the main content of the view.
        if viewModel.isAccessGranted {
            VStack(alignment: .leading) {
                LastThiefDetectionView()
                    .environment(viewModel.lastThiefDetectionViewModel)

                InfoView()
                    .environment(viewModel.infoViewModel)
            }
            .padding(viewModel.viewSettings.border) // Apply border padding from the view settings.
            .frame(width: viewModel.viewSettings.window.width)
            .accessibilityIdentifier(AccessibilityID.Main.container)
        } else { // If access isn't granted, execute the access granted block when the view appears.
            Text("")
                .onAppear {
                    viewModel.accessGrantedBlock?()
                }
        }
    }
}

#Preview("Main View") {
    MainView()
        .environment(MainViewModel.preview)
}
