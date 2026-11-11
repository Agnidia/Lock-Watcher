//
//  SettingsPage.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// One page of the settings window: a sidebar row and the form it opens.
///
/// The raw value is stored in `UISettings.lastSettingsPage`, so renaming a case drops a user's remembered page.
enum SettingsPage: String, CaseIterable, Identifiable {
    case capture
    case snapshot
    case options
    case sync
    case notifications
    case security
    case about

    var id: String {
        rawValue
    }

    var titleKey: String {
        switch self {
        case .security: "SettingsMenuSecurity"
        case .snapshot: "SettingsMenuSnapshot"
        case .capture: "SettingsMenuCapture"
        case .options: "SettingsMenuOptions"
        case .sync: "SettingsMenuSync"
        case .notifications: "SettingsMenuNotifications"
        case .about: "SettingsMenuAbout"
        }
    }

    var symbol: String {
        switch self {
        case .security: "lock.fill"
        case .snapshot: "bolt.fill"
        case .capture: "camera.fill"
        case .options: "slider.horizontal.3"
        case .sync: "icloud.fill"
        case .notifications: "bell.badge.fill"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .security: .blue
        case .snapshot: .orange
        case .capture: .indigo
        case .options: .gray
        case .sync: .cyan
        case .notifications: .red
        case .about: .teal
        }
    }
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/SettingsViewModelTests.swift
