//
//  LoginListener.swift
//
//  Created on 28.09.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Cocoa
import Combine

/// `LoginListener` monitors macOS occlusion state changes to detect user login status.
/// It leverages a lock detector to identify transitions between locked and active states.
///
/// This class is `@MainActor` isolated through `BaseListenerProtocol` conformance,
/// ensuring all state mutations occur on the main thread.
final class LoginListener: BaseListenerProtocol {
    // MARK: - Dependency Injection

    /// Logger for recording events and behavior of the login listener.
    private let logger: LogProtocol

    /// Lock detector for monitoring macOS lock state changes.
    private let lockDetector: MacOSLockDetectorProtocol

    // MARK: - Public Properties

    /// Indicates whether the listener is currently running.
    private(set) var isRunning: Bool = false

    // MARK: - Private Properties

    /// Tracks whether the system was previously in a locked state.
    private var wasLocked = false

    /// Set of Combine cancellables to manage subscriptions.
    private var cancellables: Set<AnyCancellable> = .init()

    /// Continuation for the AsyncStream to yield events.
    private var continuation: AsyncStream<ListenerEvent>.Continuation?

    /// Debounce task for login detection.
    private var debounceTask: Task<Void, Never>?

    // MARK: - Initializer

    /// Creates an instance of `LoginListener`.
    /// - Parameters:
    ///   - logger: Logger instance for event logging. Defaults to `Log` with `.loginListener` category.
    ///   - lockDetector: A protocol instance for detecting lock state changes.
    init(logger: LogProtocol = Log(category: .loginListener), lockDetector: MacOSLockDetectorProtocol) {
        self.logger = logger
        self.lockDetector = lockDetector
    }

    // MARK: - Public Methods

    /// Starts monitoring the login state.
    /// - Returns: An AsyncStream that emits events when login is detected.
    func start() -> AsyncStream<ListenerEvent> {
        logger.debug("LoginListener Started")

        return AsyncStream { continuation in
            self.continuation = continuation
            self.isRunning = true

            self.lockDetector.isLockedPublisher
                .sink(receiveValue: self.handleLockState)
                .store(in: &self.cancellables)

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.cleanup()
                }
            }
        }
    }

    /// Stops monitoring login state and clears all active subscriptions.
    func stop() {
        logger.debug("LoginListener Stopped")
        continuation?.finish()
        cleanup()
    }

    // MARK: - Private Methods

    private func cleanup() {
        isRunning = false
        continuation = nil
        wasLocked = false
        debounceTask?.cancel()
        debounceTask = nil
        cancellables.removeAll()
    }

    /// Handles changes in the lock state provided by the `lockDetector`.
    /// - Parameter isLocked: A Boolean indicating whether the system is locked.
    private func handleLockState(_ isLocked: Bool) {
        if isLocked {
            wasLocked = true
        } else if wasLocked {
            scheduleTrigger()
        }
    }

    /// Schedules a debounced trigger after 500ms delay.
    private func scheduleTrigger() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            trigger()
        }
    }

    /// Debounced function to trigger the login listener event.
    private func trigger() {
        continuation?.yield((.onLoginListener, .logedIn))
    }
}
