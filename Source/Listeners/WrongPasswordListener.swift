//
//  WrongPasswordListener.swift
//
//  Created on 09.01.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import LocalAuthentication

/// `WrongPasswordListener` monitors attempts to unlock the screen. When an unauthorized login attempt is detected,
/// it emits an event via AsyncStream.
///
/// This class is `@MainActor` isolated through `BaseListenerProtocol` conformance,
/// ensuring all state mutations occur on the main thread.
final class WrongPasswordListener: NSObject, BaseListenerProtocol {
    // MARK: - Dependency injection

    /// Logger instance for recording and debugging.
    private let logger: LogProtocol

    // MARK: - Variables

    /// XPC Service name responsible for authentication.
    private let kServiceName = "com.igrsoft.XPCAuthentication"

    /// Indicates if the listener is currently running.
    private(set) var isRunning = false

    /// Continuation for the AsyncStream to yield events.
    private var continuation: AsyncStream<ListenerEvent>.Continuation?

    /// NotificationCenter to listen Change Occlusion State
    private lazy var notificationCenter = NSWorkspace.shared.notificationCenter

    /// Indicates if the screen is currently locked.
    private var isScreenLocked = false

    /// The date of the last screen lock event.
    private var lastScreenLockDate = Date()

    /// Connection to the XPC Authentication service.
    private lazy var connection: NSXPCConnection = {
        let connection = NSXPCConnection(serviceName: kServiceName)
        connection.remoteObjectInterface = NSXPCInterface(with: XPCAuthenticationProtocol.self)
        connection.resume()

        connection.interruptionHandler = { [weak self] in
            self?.logger.error("XPCAuthentication interrupted")
        }

        connection.invalidationHandler = { [weak self] in
            self?.logger.error("XPCAuthentication invalidated")
        }

        return connection
    }()

    /// Proxy to the XPC Authentication service.
    private lazy var service: XPCAuthenticationProtocol = { [weak self] in
        self?.connection.remoteObjectProxyWithErrorHandler { error in
            self?.logger.error("Received error: \(error.localizedDescription)")
        } as! XPCAuthenticationProtocol
    }()

    // MARK: - Initializer

    /// Initializes a `WrongPasswordListener`.
    /// - Parameter logger: An instance of `Log` for logging purposes. Defaults to `.wrongPasswordListener` category.
    init(logger: LogProtocol = Log(category: .wrongPasswordListener)) {
        self.logger = logger
    }

    /// Deinitializer that invalidates the XPC connection.
    deinit {
        // Connection invalidation is handled by cleanup() when stop() is called
        // XPC connections are automatically invalidated when deallocated
    }

    // MARK: - Public Methods

    /// Starts the listener to monitor unauthorized login attempts.
    /// - Returns: An AsyncStream that emits events when wrong password is detected.
    func start() -> AsyncStream<ListenerEvent> {
        logger.debug("WrongPasswordListener Started")

        return AsyncStream { continuation in
            self.continuation = continuation
            self.isRunning = true

            self.notificationCenter.addObserver(
                self,
                selector: #selector(self.occlusionStateChanged),
                name: NSApplication.didChangeOcclusionStateNotification,
                object: nil
            )

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.cleanup()
                }
            }
        }
    }

    /// Stops the listener from monitoring unauthorized login attempts.
    func stop() {
        logger.debug("WrongPasswordListener Stopped")
        continuation?.finish()
        cleanup()
    }

    // MARK: - Private Methods

    private func cleanup() {
        isRunning = false
        continuation = nil
        notificationCenter.removeObserver(self, name: NSApplication.didChangeOcclusionStateNotification, object: nil)
    }

    /// Checks for unauthorized login attempts since the last known screen lock date.
    private func readDate() {
        logger.debug("WrongPasswordListener detecting AuthenticationFailed from \(lastScreenLockDate)")

        // XPC callback comes from non-MainActor thread, hop to MainActor
        service.detectedAuthenticationFailedFromDate(lastScreenLockDate) { [weak self] status in
            Task { @MainActor in
                self?.processAuthonticatedFailed(status: status)
            }
        }
    }

    private func processAuthonticatedFailed(status: Bool) {
        if status {
            lastScreenLockDate = Date()
            logger.debug("Detected Authentication Failed")
            continuation?.yield((.onWrongPassword, .onWrongPassword))
        }
    }

    /// Listens to the occlusion state changes to determine screen lock/unlock events.
    @MainActor @objc
    private func occlusionStateChanged() {
        if NSApp.occlusionState.contains(.visible) {
            logger.debug("screen unlocked")
            isScreenLocked = false
        } else {
            logger.debug("screen locked")

            lastScreenLockDate = Date()
            isScreenLocked = true

            readDate()
        }
    }
}
