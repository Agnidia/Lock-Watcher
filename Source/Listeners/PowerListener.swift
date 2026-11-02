//
//  PowerListener.swift
//
//  Created on 06.01.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// `PowerListener` observes power status changes by communicating with an XPC service.
/// This listener can detect when the system switches between battery power and AC power.
///
/// This class is `@MainActor` isolated through `BaseListenerProtocol` conformance,
/// ensuring all state mutations occur on the main thread.
final class PowerListener: BaseListenerProtocol {
    // MARK: - Types

    /// Enumeration representing power modes: Battery or AC.
    private enum PowerMode: Int {
        case battery = 0
        case ac = 1
    }

    // MARK: - Dependency injection

    /// Logger used for recording and debugging.
    private let logger: LogProtocol

    // MARK: - Variables

    /// The name of the XPC service used to monitor power status.
    private let kServiceName = "com.igrsoft.XPCPower"

    /// Indicates if the listener is currently monitoring power changes.
    private(set) var isRunning = false

    /// Continuation for the AsyncStream to yield events.
    private var continuation: AsyncStream<ListenerEvent>.Continuation?

    /// Connection to the XPC service.
    private lazy var connection: NSXPCConnection = {
        let connection = NSXPCConnection(serviceName: kServiceName)
        connection.remoteObjectInterface = NSXPCInterface(with: XPCPowerProtocol.self)
        connection.resume()

        connection.interruptionHandler = { [weak self] in
            self?.logger.error("XPCPower interrupted")
        }

        connection.invalidationHandler = { [weak self] in
            self?.logger.error("XPCPower invalidated")
        }

        return connection
    }()

    /// Proxy object for the XPC service.
    private lazy var service: XPCPowerProtocol = {
        connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("Received error: \(error.localizedDescription)")
        } as! XPCPowerProtocol
    }()

    // MARK: - Initializer

    /// Initializes a `PowerListener`.
    /// - Parameter logger: An instance of `Log` for logging purposes. Defaults to `.powerListener` category.
    init(logger: LogProtocol = Log(category: .powerListener)) {
        self.logger = logger
    }

    /// Deinitializer. Invalidates the XPC connection.
    deinit {
        // Connection invalidation is handled by cleanup() when stop() is called
        // XPC connections are automatically invalidated when deallocated
    }

    // MARK: - Public Methods

    /// Starts monitoring power mode changes.
    /// - Returns: An AsyncStream that emits events when power mode changes to battery.
    func start() -> AsyncStream<ListenerEvent> {
        logger.debug("PowerListener Started")

        return AsyncStream { continuation in
            self.continuation = continuation
            self.isRunning = true

            // XPC callback comes from non-MainActor thread, hop to MainActor
            self.service.startCheckPower { [weak self] mode in
                Task { @MainActor in
                    self?.process(mode: mode)
                }
            }

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.cleanup()
                }
            }
        }
    }

    /// Stops the listener from monitoring power mode changes.
    func stop() {
        logger.debug("PowerListener Stopped")
        continuation?.finish()
        cleanup()
    }

    // MARK: - Private Methods

    private func cleanup() {
        isRunning = false
        continuation = nil
        (connection.remoteObjectProxy as? XPCPowerProtocol)?.stopCheckPower()
    }

    private func process(mode: NSInteger) {
        let powerMode = PowerMode(rawValue: mode)
        logger.debug("Power switched to \(powerMode == .battery ? "Battery" : "AC Power")")

        if powerMode == .battery {
            continuation?.yield((.onBatteryPowerListener, .onBatteryPower))
        } else {
            continuation?.yield((.onBatteryPowerListener, .onACPower))
        }
    }
}
