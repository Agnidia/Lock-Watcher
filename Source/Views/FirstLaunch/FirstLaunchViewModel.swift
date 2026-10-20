//
//  FirstLaunchViewModel.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import Combine
import Observation
import SwiftUI

/// The view model for the first launch view.
@Observable
@MainActor
final class FirstLaunchViewModel: DomainViewConstantProtocol {
    // MARK: - DomainViewConstantProtocol

    /// The view's domain-specific constants.
    var viewSettings: FirstLaunchDomain = .init()

    /// The type of domain-specific constants associated with this view.
    typealias DomainViewConstant = FirstLaunchDomain

    // MARK: - Dependency injection

    /// The application's settings.
    private var settings: AppSettingsProtocol

    /// The manager responsible for handling "thief" related operations.
    private var thiefManager: ThiefManagerProtocol

    private let locationAuthorization: LocationAuthorizationProviding

    /// The closure to close the view.
    @ObservationIgnored
    private var closeClosure: Commons.EmptyClosure

    // MARK: - Variables

    /// The current state of the view.
    /// Uses `didSet` to trigger side effects when state changes.
    private(set) var state: StateMode = .idle {
        didSet {
            handleStateChange(state)
        }
    }

    /// Countdown after success before closing the window.
    private(set) var successCountDown = AppSettings.firstLaunchSuccessCount

    /// The safe area for the view.
    @ObservationIgnored
    lazy var safeArea = CGSize(width: viewSettings.window.width - ViewConstants.padding, height: viewSettings.window.height - ViewConstants.padding)

    /// Indicates if a restart is needed.
    var isNeedRestart: Bool = false

    /// Binding for `isNeedRestart` to allow two-way data binding in views.
    var isNeedRestartBinding: Binding<Bool> {
        Binding(
            get: { self.isNeedRestart },
            set: { self.isNeedRestart = $0 }
        )
    }

    /// Indicates if an alert should be shown.
    var showingAlert = false

    /// Binding for `showingAlert` to allow two-way data binding in views.
    var showingAlertBinding: Binding<Bool> {
        Binding(
            get: { self.showingAlert },
            set: { self.showingAlert = $0 }
        )
    }

    /// A timer for tracking time-based operations.
    private var timer: Timer?

    /// View model for the first launch options.
    @ObservationIgnored
    lazy var firstLaunchOptionsViewModel: FirstLaunchOptionsViewModel = {
        FirstLaunchOptionsViewModel(settings: settings, locationAuthorization: locationAuthorization)
    }()

    // MARK: - Combine

    /// Collection of cancellable publishers to clean up when done.
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initializer
    
    /// Initializes the view model with dependencies.
    init(settings: AppSettingsProtocol, thiefManager: ThiefManagerProtocol, locationAuthorization: LocationAuthorizationProviding = LocationAuthorizationService(), closeClosure: @escaping Commons.EmptyClosure) {
        self.settings = settings
        self.thiefManager = thiefManager
        self.locationAuthorization = locationAuthorization
        self.closeClosure = closeClosure
    }
    
    /// Stops any active timers.
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - ViewBuilder Methods
    
    /// Provides the text for taking a snapshot.
    func takeSnapshotTitle() -> Text {
        Text("TakeSnapshotAndStart")
    }
    
    /// Simulates taking a snapshot and starts a process.
    func takeSnapshot() {
        state = .progress
    }
    
    /// Provides the title for the alert to open settings.
    func openSettingsAlertTitle() -> Text {
        Text("OpenSettings")
    }
    
    /// Provides the button title to open settings.
    func openSettingsTitle() -> Text {
        Text("ButtonSettings")
    }
    
    /// Opens the settings for the application.
    func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
    }
    
    /// Provides the cancel button title for the settings alert.
    func cancelSettingsTitle() -> Text {
        Text("ButtonCancel")
    }
    
    /// Restarts the view to its initial state.
    func restartView() -> some View {
        Text("")
            .onAppear { [weak self] in
                self?.state = .idle
            }
    }
    
    // MARK: - Private Methods

    /// Handles state changes and triggers appropriate side effects.
    private func handleStateChange(_ state: StateMode) {
        switch state {
        case .idle:
            isNeedRestart = false
        case .progress:
            simulateTrigger()
        case .success:
            startTimerToCloseWindow()
        case .fault:
            showingAlert = true
        case .anonymous, .authorised:
            break
        }
    }
    
    /// Simulates a trigger for permissions and state changes.
    private func simulateTrigger() {
        PermissionsUtils.updateCameraPermissions { [weak self] isGranted in
            Task { @MainActor in
                guard let self else { return }
                if isGranted {
                    let success = await self.thiefManager.detectedTrigger()
                    self.state = success ? .success : .fault
                } else {
                    self.state = .fault
                }
            }
        }
    }
    
    /// Starts a timer to close the window after the success countdown is completed.
    private func startTimerToCloseWindow() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.successCountDown == .zero {
                    self.stopTimer()
                    self.closeClosure()
                } else {
                    self.successCountDown -= 1
                }
            }
        }
    }
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/FirstLaunchViewModelTests.swift

/// Provides a preview version of the `FirstLaunchViewModel`.
extension FirstLaunchViewModel {
    static var preview: FirstLaunchViewModel {
        FirstLaunchViewModel(settings: AppSettingsPreview(), thiefManager: ThiefManagerPreview(), closeClosure: {})
    }
}
