//
//  TriggerManager.swift
//
//  Created on 06.01.2021.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import CoreLocation
import Foundation

/// MainActor-isolated trigger closure type
typealias MainActorTriggerClosure = @MainActor (TriggerType) -> Void

/// Defines a protocol for trigger management.
///
/// - Important: All trigger managers are `@MainActor` isolated because they
///   interact with `@MainActor` listeners and UI callbacks.
@MainActor
protocol TriggerManagerProtocol: Sendable {
    /// Starts the trigger manager with given settings and an optional trigger block.
    func start(settings: AppSettingsProtocol?, triggerBlock: @escaping MainActorTriggerClosure)

    /// Stops all running triggers.
    func stop()
}

/// Builds the listener for a name, or `nil` when the build does not ship it.
typealias ListenerFactory = @MainActor (ListenerName, MacOSLockDetectorProtocol, TriggerSettings) -> BaseListenerProtocol?

/// Manages trigger listeners and coordinates event dispatching.
///
/// This class is `@MainActor` isolated because it manages `@MainActor` listeners
/// and dispatches callbacks to the main thread.
@MainActor
final class TriggerManager: TriggerManagerProtocol {
    // MARK: - Dependency injection

    /// Holds the application settings.
    private var settings: AppSettingsProtocol?

    /// Logger for module
    private let logger: LogProtocol

    /// The trigger block to call when events occur.
    private var triggerBlock: MainActorTriggerClosure?

    private let lockDetector: MacOSLockDetectorProtocol

    private let makeListener: ListenerFactory

    private let locationAuthorization: LocationAuthorizationProviding
    private var authorizationObservation: LocationAuthorizationObservation?
    private var isWatching = false

    /// Tasks consuming listener streams.
    private var listenerTasks: [ListenerName: Task<Void, Never>] = [:]

    /// The delay the current locked-input listener was built with.
    private var lockedInputDelayInUse: Int?

    private var currentTriggers: TriggerSettings {
        settings?.triggers ?? TriggerSettings()
    }

    /// One listener per name the build ships.
    private lazy var listeners: [ListenerName: BaseListenerProtocol] = Dictionary(
        uniqueKeysWithValues: ListenerName.allCases.compactMap { name in
            buildListener(name).map { (name, $0) }
        }
    )

    init(logger: LogProtocol = Log(category: .triggerManager),
         lockDetector: MacOSLockDetectorProtocol = MacOSLockDetector(),
         locationAuthorization: LocationAuthorizationProviding = LocationAuthorizationService(),
         makeListener: @escaping ListenerFactory = TriggerManager.defaultListener)
    {
        self.logger = logger
        self.lockDetector = lockDetector
        self.locationAuthorization = locationAuthorization
        self.makeListener = makeListener
        authorizationObservation = locationAuthorization.observeAuthorization { [weak self] status in
            self?.reconcileGeofence(status: status)
        }
    }

    static func defaultListener(_ name: ListenerName, _ lockDetector: MacOSLockDetectorProtocol, _ triggers: TriggerSettings) -> BaseListenerProtocol? {
        switch name {
        case .onWakeUpListener: WakeUpListener()
        case .onWrongPassword: AppSettings.isMASBuild ? nil : WrongPasswordListener()
        case .onBatteryPowerListener: PowerListener()
        case .onUSBConnectionListener: USBListener()
        case .onLoginListener: LoginListener(lockDetector: lockDetector)
        case .onDisplayListener: DisplayListener(lockDetector: lockDetector)
        case .onGeofenceListener: GeofenceListener(lockDetector: lockDetector)
        case .onLockedInputListener: LockedInputListener(lockDetector: lockDetector, grace: TimeInterval(triggers.lockedInputDelay))
        }
    }

    // MARK: - public

    /// Starts all listeners based on provided settings.
    func start(settings: AppSettingsProtocol?, triggerBlock: @escaping MainActorTriggerClosure = { _ in }) {
        logger.debug("Starting all triggers")

        self.settings = settings
        self.triggerBlock = triggerBlock
        isWatching = true

        locationAuthorization.refreshAuthorization()

        applyLockedInputDelay()

        startListener(.onWakeUpListener, enabled: settings?.triggers.isUseSnapshotOnWakeUp == true)
        startListener(.onWrongPassword, enabled: settings?.triggers.isUseSnapshotOnWrongPassword == true)
        startListener(.onBatteryPowerListener, enabled: settings?.triggers.isUseSnapshotOnSwitchToBatteryPower == true)
        startListener(.onUSBConnectionListener, enabled: settings?.triggers.isUseSnapshotOnUSBMount == true)
        startListener(.onLoginListener, enabled: settings?.triggers.isUseSnapshotOnLogin == true)
        startListener(.onDisplayListener, enabled: settings?.triggers.isUseSnapshotOnDisplayAttach == true)
        startListener(.onLockedInputListener, enabled: settings?.triggers.isUseSnapshotOnLockedInput == true)
    }

    /// Stops all active listeners.
    func stop() {
        logger.debug("Stop all triggers")
        isWatching = false

        for (_, task) in listenerTasks {
            task.cancel()
        }
        listenerTasks.removeAll()

        for listener in listeners.values {
            listener.stop()
        }
    }

    // MARK: - private

    private func reconcileGeofence(status: CLAuthorizationStatus) {
        guard let settings else {
            startListener(.onGeofenceListener, enabled: false)
            return
        }

        if status != .authorizedAlways, !(status == .notDetermined && locationAuthorization.isRequestPending), settings.triggers.isUseSnapshotOnLocationChange {
            var triggers = settings.triggers
            triggers.isUseSnapshotOnLocationChange = false
            self.settings?.triggers = triggers
        }

        startListener(.onGeofenceListener, enabled: isWatching && status == .authorizedAlways && settings.triggers.isUseSnapshotOnLocationChange)
    }

    /// A listener can hold an open stream while `isRunning` is false (geofence without
    /// authorization), so a disabled flag stops any listener that still has a task.
    private func startListener(_ name: ListenerName, enabled: Bool) {
        guard let listener = listeners[name] else { return }

        if enabled {
            guard !listener.isRunning else { return }

            let stream = listener.start()
            listenerTasks[name]?.cancel()
            listenerTasks[name] = Task { [weak self] in
                for await (listenerName, triggerType) in stream {
                    // Already on MainActor, call directly
                    if triggerType != .onACPower {
                        self?.triggerBlock?(triggerType)
                    }
                    self?.listenerDidFire(listenerName)
                }
            }
        } else {
            let task = listenerTasks.removeValue(forKey: name)
            task?.cancel()
            if task != nil || listener.isRunning {
                listener.stop()
            }
        }
    }

    /// A fresh instance stays unarmed until the next lock, which bounds most listeners to one fire per lock period;
    /// a listener that re-arms itself is kept, so its own state rules out a second fire for one input.
    private func listenerDidFire(_ name: ListenerName) {
        guard listeners[name]?.keepsRunningAfterEvent != true else { return }
        restartListener(type: name)
    }

    /// Replaces a listener with a fresh instance after it yields.
    private func restartListener(type: ListenerName) {
        listenerTasks[type]?.cancel()
        listenerTasks[type] = nil
        listeners[type]?.stop()

        listeners[type] = buildListener(type)
        let geofenceAllowed = type != .onGeofenceListener || (isWatching && locationAuthorization.authorizationStatus == .authorizedAlways && currentTriggers.isUseSnapshotOnLocationChange)
        startListener(type, enabled: geofenceAllowed)
    }

    private func buildListener(_ name: ListenerName) -> BaseListenerProtocol? {
        let triggers = currentTriggers
        if name == .onLockedInputListener {
            lockedInputDelayInUse = triggers.lockedInputDelay
        }
        return makeListener(name, lockDetector, triggers)
    }

    /// The delay is fixed per listener instance, so a changed value replaces the listener; `startListener` then starts it if enabled.
    private func applyLockedInputDelay() {
        guard let inUse = lockedInputDelayInUse, inUse != currentTriggers.lockedInputDelay else { return }

        listenerTasks.removeValue(forKey: .onLockedInputListener)?.cancel()
        listeners[.onLockedInputListener]?.stop()
        listeners[.onLockedInputListener] = buildListener(.onLockedInputListener)
    }
}

// MARK: - Test Info

// @test-file: Tests/Managers/TriggerManagerTest.swift
// @related-tests: Tests/Listeners/GeofenceListenerTests.swift
