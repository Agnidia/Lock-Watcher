//
//  LockGraceGate.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Lock-period state machine for listeners that may fire only while the session stays locked.
///
/// Feed every lock-detector tick to `tick(isLocked:now:)`. Only an observed unlocked → locked
/// transition arms a period, so an instance created mid-lock (for example after
/// `TriggerManager` restarts a listener) stays silent until the next lock. An armed period
/// fires at most once.
struct LockGraceGate: Sendable, Equatable {
    enum Event: Sendable, Equatable {
        case none
        case didLock
        case didUnlock
        case fire
    }

    enum LockState: Sendable, Equatable {
        case unknown
        case unlocked
        case locked
    }

    private enum Phase: Sendable, Equatable {
        case unknown
        case unlocked
        case lockedUnarmed
        case armed
        case spent
    }

    /// How long the lock must hold after a proposed event before it fires.
    let grace: TimeInterval

    /// Start of the armed lock period; `nil` outside one.
    private(set) var lockedSince: Date?

    private var phase: Phase = .unknown
    private var pendingSince: Date?

    init(grace: TimeInterval) {
        self.grace = grace
    }

    var lockState: LockState {
        switch phase {
        case .unknown: .unknown
        case .unlocked: .unlocked
        case .lockedUnarmed, .armed, .spent: .locked
        }
    }

    var hasPendingProposal: Bool {
        pendingSince != nil
    }

    /// True while an armed period has neither a pending event nor a fired one.
    var acceptsProposal: Bool {
        phase == .armed && pendingSince == nil
    }

    /// Applies the lock transition first, then checks whether a pending event has matured.
    mutating func tick(isLocked: Bool, now: Date) -> Event {
        guard isLocked else {
            let wasUnlocked = phase == .unlocked
            phase = .unlocked
            lockedSince = nil
            pendingSince = nil
            return wasUnlocked ? .none : .didUnlock
        }

        switch phase {
        case .unknown:
            phase = .lockedUnarmed
            return .none
        case .unlocked:
            phase = .armed
            lockedSince = now
            return .didLock
        case .lockedUnarmed, .spent:
            return .none
        case .armed:
            guard let pendingSince, now.timeIntervalSince(pendingSince) >= grace else { return .none }
            self.pendingSince = nil
            phase = .spent
            return .fire
        }
    }

    /// Starts the grace window at `date`; ignored unless `acceptsProposal`.
    mutating func propose(at date: Date) {
        guard acceptsProposal else { return }
        pendingSince = date
    }

    /// Re-opens a spent period while the lock holds; `lockedSince` is kept, so the lock-start window does not apply again.
    mutating func rearm() {
        guard phase == .spent else { return }
        pendingSince = nil
        phase = .armed
    }

    /// Spends the armed period at once, for sources that need no grace window.
    /// - Returns: `true` when the period was armed and not yet spent.
    mutating func fireNow() -> Bool {
        guard phase == .armed else { return false }
        pendingSince = nil
        phase = .spent
        return true
    }
}

// MARK: - Test Info

// @test-file: Tests/Listeners/LockGraceGateTests.swift
