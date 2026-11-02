//
//  WakeUpListener.swift
//
//  Created on 09.01.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Cocoa
import Foundation

/// `WakeUpListener` observes the system for screen wake up events and emits events via AsyncStream.
///
/// This class is `@MainActor` isolated through `BaseListenerProtocol` conformance,
/// ensuring all state mutations occur on the main thread.
final class WakeUpListener: NSObject, BaseListenerProtocol {
    // MARK: - Dependency injection

    /// Logger instance used for recording and debugging purposes.
    private let logger: LogProtocol

    // MARK: - Variables

    /// Indicates if the listener is currently monitoring screen wake up events.
    private(set) var isRunning: Bool = false

    /// Continuation for the AsyncStream to yield events.
    private var continuation: AsyncStream<ListenerEvent>.Continuation?

    /// NotificationCenter to monitor screen wake up events.
    private lazy var notificationCenter = NSWorkspace.shared.notificationCenter

    // MARK: - Initializer

    /// Initializes a `WakeUpListener`.
    /// - Parameter logger: An instance of `Log` for logging purposes. Defaults to `.wakeUpListener` category.
    init(logger: LogProtocol = Log(category: .wakeUpListener)) {
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Starts monitoring for screen wake up events.
    /// - Returns: An AsyncStream that emits events when screen wake up is detected.
    func start() -> AsyncStream<ListenerEvent> {
        logger.debug("WakeUpListener started")

        return AsyncStream { continuation in
            self.continuation = continuation
            self.isRunning = true

            self.notificationCenter.addObserver(
                self,
                selector: #selector(self.receiveWakeNotification),
                name: NSWorkspace.screensDidWakeNotification,
                object: nil
            )

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.cleanup()
                }
            }
        }
    }

    /// Stops the listener from monitoring screen wake up events.
    func stop() {
        logger.debug("WakeUpListener Stopped")
        continuation?.finish()
        cleanup()
    }

    // MARK: - Private Methods

    private func cleanup() {
        isRunning = false
        continuation = nil
        notificationCenter.removeObserver(self, name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    /// Handles the screen wake up event notification.
    @objc
    private func receiveWakeNotification() {
        continuation?.yield((.onWakeUpListener, .onWakeUp))
    }
}
