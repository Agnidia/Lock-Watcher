//
//  BaseListenerProtocol.swift
//
//  Created on 06.01.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// An enumeration representing the names of different listeners.
///
/// This enum identifies each listener that can be installed to monitor
/// specific system events, such as waking up from sleep or detecting
/// a USB connection.
public enum ListenerName: Int, CaseIterable, Sendable {
    case onWakeUpListener           // Triggered when the system wakes up.
    case onWrongPassword            // Triggered when a wrong password is entered.
    case onBatteryPowerListener     // Triggered when the system switches to battery power.
    case onUSBConnectionListener    // Triggered when a USB device is connected.
    case onLoginListener            // Triggered when a user logs in.
    case onDisplayListener          // Triggered when a display is attached while locked.
    case onGeofenceListener         // Triggered when the Mac moves while locked.
    case onLockedInputListener      // Triggered by keyboard or mouse input while locked.
}

/// The event type emitted by listeners through AsyncStream.
public typealias ListenerEvent = (ListenerName, TriggerType)

/// A protocol defining the contract for listeners.
///
/// Conformers to this protocol are expected to monitor specific
/// events and emit them via an AsyncStream when these events occur.
///
/// - Important: All listeners are `@MainActor` isolated because they interact with
///   system APIs (NotificationCenter, XPC) that require main thread access.
@MainActor
public protocol BaseListenerProtocol: Sendable {
    /// A boolean indicating whether the listener is currently running.
    ///
    /// This can be used to check if the listener is actively monitoring events.
    var isRunning: Bool { get }

    /// Starts the listener and returns an AsyncStream of events.
    ///
    /// When the listener detects its corresponding event, it yields
    /// the event to the stream. Events are delivered on the main actor.
    ///
    /// - Returns: An AsyncStream that emits `ListenerEvent` tuples when triggers are detected.
    func start() -> AsyncStream<ListenerEvent>

    /// Stops the listener from monitoring its corresponding event.
    ///
    /// After calling this method, the listener will no longer detect its
    /// trigger until `start` is called again. The AsyncStream will finish.
    func stop()

    /// `true` when the listener re-arms itself after an event, so `TriggerManager` keeps the instance instead of replacing it.
    var keepsRunningAfterEvent: Bool { get }
}

extension BaseListenerProtocol {
    public var keepsRunningAfterEvent: Bool {
        false
    }
}

// MARK: - Test Info

// @test-file: Tests/Listeners/ListenerProtocolTest.swift
