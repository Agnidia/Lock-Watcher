//
//  MainCoordinator.swift
//
//  Created on 29.06.2023.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import AppKit
import SwiftUI

/// `MainCoordinator` manages and coordinates the main window of the application, especially its display and authentication.
@MainActor
final class MainCoordinator: BaseCoordinatorProtocol {
    // MARK: - Dependency Injection
    
    /// Configuration settings for the application.
    private var settings: AppSettingsProtocol
    
    private let authManager: AuthentificationManager
    
    /// Likely manages data or tasks related to unauthorized access.
    private var thiefManager: ThiefManagerProtocol

    private let locationAuthorization: LocationAuthorizationProviding
    
    // MARK: - Variables
    
    /// ViewModel for the main view.
    private lazy var mainViewModel = MainViewModel(thiefManager: thiefManager)
    
    /// Logger instance for this module.
    private let logger: LogProtocol
    
    /// Popover displayed from the status bar icon.
    @MainActor
    private lazy var mainPopover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSViewController()
        let root = MainView().environment(mainViewModel)
        let hostingView = NSHostingView(rootView: root)
        popover.contentViewController?.view = hostingView

        return popover
    }()
    
    /// Status bar button that connects to the popover to display the main window.
    private let statusBarButton: NSStatusBarButton
    
    /// Window displayed during the application's first launch.
    private var firstLaunchWindow: NSWindow?
    
    // MARK: - Initialiser
    
    /// Initializes a new `MainCoordinator`.
    ///
    /// - Parameters:
    ///     - logger: Logger instance.
    ///     - settings: Application settings.
    ///     - thiefManager: Manager related to unauthorized access.
    ///     - statusBarButton: Status bar button to toggle the main window.
    init(logger: LogProtocol = Log(category: .coordinator), settings: AppSettingsProtocol, thiefManager: ThiefManagerProtocol, statusBarButton: NSStatusBarButton, securityUtil: SecurityUtilProtocol, locationAuthorization: LocationAuthorizationProviding = LocationAuthorizationService()) {
        self.logger = logger
        self.settings = settings
        self.thiefManager = thiefManager
        self.locationAuthorization = locationAuthorization
        self.statusBarButton = statusBarButton
        authManager = .init(logger: logger, securityUtil: securityUtil)
    }
    
    // MARK: - Public Functions
    
    /// Displays the main window after showing a security access alert.
    func displayMainWindow() {
        Task { @MainActor in
            if await authenticateIfNeeded() {
                statusBarButton.image = .statusBarIcon()
                showPopover(for: statusBarButton)
            }
        }
    }
    
    private func authenticateIfNeeded() async -> Bool {
        if !settings.options.isProtected {
            return true
        } else {
            do {
                return try await authManager.authenticate(with: settings.options.authSettings)
            } catch {
                NSApp.presentError(error)
                return false
            }
        }
    }
    
    /// Closes the main window.
    func closeMainWindow() {
        closePopover(statusBarButton)
    }
    
    /// Toggles the visibility of the main window.
    func toggleMainWindow() {
        if mainPopover.isShown {
            closeMainWindow()
        } else {
            displayMainWindow()
        }
    }
    
    /// Displays a window on the first launch of the app.
    ///
    /// - Parameter closeClosure: Callback executed when the window is closed.
    func displayFirstLaunchWindowIfNeed(closeClosure: @escaping Commons.EmptyClosure) {
        if settings.options.isFirstLaunch {
            settings.options.isFirstLaunch = false
            let firstLaunchViewModel = FirstLaunchViewModel(
                settings: settings,
                thiefManager: thiefManager,
                locationAuthorization: locationAuthorization,
                closeClosure: { [weak self] in
                    self?.firstLaunchWindow?.close()
                    closeClosure()
                }
            )
            
            firstLaunchWindow = FirstLaunchView()
                .environment(firstLaunchViewModel)
                .openInWindow(title: NSLocalizedString("FirstLaunchSetup", comment: ""), sender: self)
        }
    }
    
    /// Displays the settings window.
    func displaySettingsWindow() {
        NSApplication.displaySettingsWindow()
    }
    
    // MARK: - Private Functions
    
    /// Displays the popover below the provided status bar button.
    ///
    /// - Parameter button: The status bar button.
    private func showPopover(for button: NSStatusBarButton) {
        mainPopover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
    }
    
    /// Closes the popover.
    ///
    /// - Parameter sender: The UI component triggering the close action.
    private func closePopover(_ sender: NSStatusBarButton?) {
        mainPopover.performClose(sender)
    }
}

// MARK: - Test Info

// @test-file: Tests/Coordinator/MainCoordinatorTest.swift
