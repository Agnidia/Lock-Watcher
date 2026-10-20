//
//  InfoViewModel.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import Observation
import SwiftUI

/// A view model designed to manage the data and behaviors for the information section.
@Observable
@MainActor
final class InfoViewModel {
    /// The thief manager responsible for handling thief-related actions and data.
    let thiefManager: ThiefManagerProtocol

    /// Initializes a new `InfoViewModel`.
    ///
    /// - Parameters:
    ///   - thiefManager: The thief manager for this view model.
    ///   - isInfoExtended: A binding to control whether the info is extended.
    init(thiefManager: ThiefManagerProtocol) {
        self.thiefManager = thiefManager
    }

    /// Provides the title for the debug section.
    func debugTitle() -> Text {
        Text("Debug")
    }

    /// Invokes the thief manager's detected trigger.
    func debugTrigger() {
        Task {
            _ = await thiefManager.detectedTrigger()
        }
    }

    /// Provides the title for the clean button.
    func cleanTitle() -> Text {
        Text("Clean")
    }

    /// Cleans all data: resets database and app settings to defaults.
    func cleanAll() {
        thiefManager.cleanAll()
    }

    /// Provides the title for the open settings button.
    func openSettingsTitle() -> Text {
        Text("ButtonSettings")
    }

    /// Opens the application's settings window.
    func openSettings() {
        NSApplication.displaySettingsWindow()
    }
    
    /// Provides the title for the quit application button.
    func quitAppTitle() -> Text {
        Text("Quit")
    }
    
    /// Quits the application.
    func quitApp() {
        exit(0)
    }
    
    /// The text for a link in the view.
    let linkText: String = "© Agnidia 2008 - 2026"
    
    /// The URL corresponding to the link text.
    let linkUrl: URL = .init(string: "https://igrsoft.com")!
}
