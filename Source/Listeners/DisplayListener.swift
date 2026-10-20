//
//  DisplayListener.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Combine
import CoreGraphics
import Foundation

/// Emits `.displayAttached` when a display that was not online at lock time appears while the
/// session is locked, and the lock still holds after the grace window.
///
/// Diffing display IDs on the lock detector's tick ignores resolution changes and wake
/// reconfiguration by construction, which `didChangeScreenParametersNotification` would not.
final class DisplayListener: BaseListenerProtocol {
    // MARK: - Dependency injection

    private let logger: LogProtocol
    private let lockDetector: MacOSLockDetectorProtocol

    /// Returns `nil` when the display list cannot be read.
    private let onlineDisplayIDs: @MainActor () -> Set<CGDirectDisplayID>?
    private let now: @MainActor () -> Date
    private let grace: TimeInterval

    // MARK: - Variables

    private(set) var isRunning: Bool = false

    private var continuation: AsyncStream<ListenerEvent>.Continuation?
    private var cancellables: Set<AnyCancellable> = .init()
    private var gate: LockGraceGate

    /// Displays online when the armed period began; `nil` disables detection for that period.
    private var displaysAtLock: Set<CGDirectDisplayID>?

    /// Lets a late `onTermination` from a replaced stream skip the newer stream's state.
    private var generation = 0

    // MARK: - Initializer

    init(logger: LogProtocol = Log(category: .displayListener),
         lockDetector: MacOSLockDetectorProtocol,
         onlineDisplayIDs: @escaping @MainActor () -> Set<CGDirectDisplayID>? = DisplayListener.onlineDisplayIDs,
         now: @escaping @MainActor () -> Date = Date.init,
         grace: TimeInterval = 10)
    {
        self.logger = logger
        self.lockDetector = lockDetector
        self.onlineDisplayIDs = onlineDisplayIDs
        self.now = now
        self.grace = grace
        gate = LockGraceGate(grace: grace)
    }

    // MARK: - Public Methods

    func start() -> AsyncStream<ListenerEvent> {
        logger.debug("DisplayListener Started")
        teardown()
        generation += 1
        let streamGeneration = generation

        return AsyncStream { continuation in
            self.continuation = continuation
            self.isRunning = true

            self.lockDetector.isLockedPublisher
                .sink { [weak self] isLocked in
                    self?.handleTick(isLocked: isLocked)
                }
                .store(in: &self.cancellables)

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.cleanup(generation: streamGeneration)
                }
            }
        }
    }

    func stop() {
        logger.debug("DisplayListener Stopped")
        teardown()
    }

    // MARK: - Private Methods

    private func teardown() {
        let open = continuation
        continuation = nil
        open?.finish()
        reset()
    }

    private func cleanup(generation streamGeneration: Int) {
        guard streamGeneration == generation else { return }
        continuation = nil
        reset()
    }

    private func reset() {
        isRunning = false
        cancellables.removeAll()
        gate = LockGraceGate(grace: grace)
        displaysAtLock = nil
    }

    private func handleTick(isLocked: Bool) {
        let tickDate = now()

        switch gate.tick(isLocked: isLocked, now: tickDate) {
        case .didLock:
            displaysAtLock = onlineDisplayIDs()
            if displaysAtLock == nil {
                logger.error("DisplayListener could not read the display list at lock time")
            }
            return
        case .didUnlock:
            displaysAtLock = nil
            return
        case .fire:
            logger.info("Display attached while locked")
            continuation?.yield((.onDisplayListener, .displayAttached))
            return
        case .none:
            break
        }

        guard gate.acceptsProposal, let displaysAtLock, let current = onlineDisplayIDs() else { return }
        if !current.subtracting(displaysAtLock).isEmpty {
            gate.propose(at: tickDate)
        }
    }

    /// Online rather than active displays, so a display that sleeps while locked keeps its ID.
    static func onlineDisplayIDs() -> Set<CGDirectDisplayID>? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success else { return nil }
        guard count > 0 else { return [] }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return nil }
        return Set(ids.prefix(Int(count)))
    }
}

// MARK: - Test Info

// @test-file: Tests/Listeners/DisplayListenerTests.swift
