//
//  App.swift
//
//  Created on 29.06.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// Represents the main entry point of the application.
@main
struct MainApp: App {
    /// The application delegate to handle system-level events.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Defines the main scene for the application.
    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.viewModel.settingsViewModel)
        }
    }
}
