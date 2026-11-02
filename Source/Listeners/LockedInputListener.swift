//
//  LockedInputListener.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Combine
import CoreGraphics
import Foundation

/// Emits `.lockedInput` when a key press or mouse click happens while the session is locked,
/// later than `lockStartWindow` after the lock began, and the lock still holds `grace` seconds
/// after the tick that detected it.
///
/// Reads the HID idle counter on the lock detector's tick, so it needs no Accessibility or
/// Input Monitoring permission and never sees which key was pressed.
///
/// After a fire it re-arms itself `rearmCooldown` seconds later while the lock holds, so it keeps
/// its state across its own events and `TriggerManager` must not replace it after one.
final class LockedInputListener: BaseListenerProtocol {
    // MARK: - Dependency injection

    private let logger: LogProtocol
    private let lockDetector: MacOSLockDetectorProtocol
    private let secondsSinceInput: @MainActor () -> TimeInterval
    private let now: @MainActor () -> Date
    /// Seconds the lock must hold after detected input; `0` fires on the next locked tick.
    let grace: TimeInterval
    private let lockStartWindow: TimeInterval
    private let rearmCooldown: TimeInterval

    // MARK: - Variables

    private(set) var isRunning: Bool = false

    let keepsRunningAfterEvent = true

    /// End of the post-fire cooldown; `nil` when none is running.
    private var cooldownUntil: Date?

    private var continuation: AsyncStream<ListenerEvent>.Continuation?
    private var cancellables: Set<AnyCancellable> = .init()
    private var gate: LockGraceGate

    /// Idle seconds read on the previous armed tick.
    private var lastIdle: TimeInterval?

    /// Lets a late `onTermination` from a replaced stream skip the newer stream's state.
    private var generation = 0

    // MARK: - Initializer

    init(logger: LogProtocol = Log(category: .lockedInputListener),
         lockDetector: MacOSLockDetectorProtocol,
         secondsSinceInput: @escaping @MainActor () -> TimeInterval = LockedInputListener.secondsSinceUserInput,
         now: @escaping @MainActor () -> Date = Date.init,
         grace: TimeInterval = 2,
         lockStartWindow: TimeInterval = 5,
         rearmCooldown: TimeInterval = 30)
    {
        self.logger = logger
        self.lockDetector = lockDetector
        self.secondsSinceInput = secondsSinceInput
        self.now = now
        self.grace = grace
        self.lockStartWindow = lockStartWindow
        self.rearmCooldown = rearmCooldown
        gate = LockGraceGate(grace: grace)
    }

    // MARK: - Public Methods

    func start() -> AsyncStream<ListenerEvent> {
        logger.debug("LockedInputListener Started")
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
        logger.debug("LockedInputListener Stopped")
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
        lastIdle = nil
        cooldownUntil = nil
    }

    private func handleTick(isLocked: Bool) {
        let tickDate = now()
        let wasPending = gate.hasPendingProposal

        switch gate.tick(isLocked: isLocked, now: tickDate) {
        case .fire:
            logger.info("Locked input: lock held for \(Int(grace)) s, capturing")
            continuation?.yield((.onLockedInputListener, .lockedInput))
            cooldownUntil = tickDate.addingTimeInterval(rearmCooldown)
            lastIdle = nil
            logger.debug("Locked input: cooldown started (\(Int(rearmCooldown)) s)")
            return
        case .didUnlock:
            if wasPending {
                logger.debug("Locked input: unlocked before the \(Int(grace)) s delay expired, capture cancelled")
            }
            if cooldownUntil != nil {
                logger.debug("Locked input: unlocked during the cooldown, cooldown cancelled")
            }
            cooldownUntil = nil
        default:
            break
        }

        if let cooldownUntil, gate.lockState == .locked {
            runCooldown(until: cooldownUntil, tickDate: tickDate)
            return
        }

        guard gate.acceptsProposal, let lockedSince = gate.lockedSince else {
            lastIdle = nil
            return
        }

        let idle = secondsSinceInput()
        logger.debug("Locked idle seconds: \(idle)")

        // The idle counter pauses across system sleep while the wall clock runs on, so only a drop between ticks is input.
        let isNewInput = lastIdle.map { idle < $0 } ?? false
        lastIdle = idle

        guard isNewInput else { return }

        if tickDate.timeIntervalSince(lockedSince) > lockStartWindow {
            gate.propose(at: tickDate)
            logger.debug("Locked input: input detected, capture queued in \(Int(grace)) s if the lock holds")
        } else {
            logger.debug("Locked input: input inside the \(Int(lockStartWindow)) s lock-start window, ignored")
        }
    }

    /// Input during the cooldown is dropped; re-arming clears the idle baseline so it cannot carry over.
    private func runCooldown(until end: Date, tickDate: Date) {
        let idle = secondsSinceInput()
        if let lastIdle, idle < lastIdle {
            logger.debug("Locked input: input during the cooldown, ignored")
        }
        lastIdle = idle

        guard tickDate >= end else { return }

        cooldownUntil = nil
        lastIdle = nil
        gate.rearm()
        logger.debug("Locked input: re-armed after the cooldown")
    }

    /// Mouse moves and scrolls are left out, so a bumped desk does not count as input.
    static func secondsSinceUserInput() -> TimeInterval {
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        return types
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? .greatestFiniteMagnitude
    }
}

// MARK: - Test Info

// @test-file: Tests/Listeners/LockedInputListenerTests.swift
