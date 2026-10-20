//
//  LockGraceGateTests.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

/// @test-required
final class LockGraceGateTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    func testUnlockedToLockedArmsPeriod() {
        var gate = LockGraceGate(grace: 10)

        XCTAssertEqual(gate.tick(isLocked: false, now: at(0)), .didUnlock)
        XCTAssertEqual(gate.lockState, .unlocked)
        XCTAssertEqual(gate.tick(isLocked: true, now: at(1)), .didLock)
        XCTAssertEqual(gate.lockedSince, at(1))
        XCTAssertTrue(gate.acceptsProposal)
    }

    func testFirstTickLockedStaysUnarmed() {
        var gate = LockGraceGate(grace: 10)

        XCTAssertEqual(gate.tick(isLocked: true, now: at(0)), .none)
        XCTAssertEqual(gate.lockState, .locked)
        XCTAssertNil(gate.lockedSince)
        XCTAssertFalse(gate.acceptsProposal)

        gate.propose(at: at(1))
        XCTAssertEqual(gate.tick(isLocked: true, now: at(30)), .none)
    }

    func testProposalFiresOnceAfterGrace() {
        var gate = LockGraceGate(grace: 10)
        _ = gate.tick(isLocked: false, now: at(0))
        _ = gate.tick(isLocked: true, now: at(1))

        gate.propose(at: at(5))
        XCTAssertFalse(gate.acceptsProposal)
        XCTAssertEqual(gate.tick(isLocked: true, now: at(14)), .none)
        XCTAssertEqual(gate.tick(isLocked: true, now: at(15)), .fire)

        gate.propose(at: at(16))
        XCTAssertEqual(gate.tick(isLocked: true, now: at(40)), .none)
    }

    func testUnlockInsideGraceDropsProposal() {
        var gate = LockGraceGate(grace: 10)
        _ = gate.tick(isLocked: false, now: at(0))
        _ = gate.tick(isLocked: true, now: at(1))
        gate.propose(at: at(5))

        XCTAssertEqual(gate.tick(isLocked: false, now: at(8)), .didUnlock)
        XCTAssertNil(gate.lockedSince)
        XCTAssertEqual(gate.tick(isLocked: false, now: at(20)), .none)
    }

    func testNextLockRearmsAfterFire() {
        var gate = LockGraceGate(grace: 0)
        _ = gate.tick(isLocked: false, now: at(0))
        _ = gate.tick(isLocked: true, now: at(1))
        XCTAssertTrue(gate.fireNow())
        XCTAssertFalse(gate.fireNow())

        _ = gate.tick(isLocked: false, now: at(2))
        XCTAssertEqual(gate.tick(isLocked: true, now: at(3)), .didLock)
        XCTAssertTrue(gate.fireNow())
    }

    func testRearmReopensASpentPeriodAndKeepsLockStart() {
        var gate = LockGraceGate(grace: 10)
        _ = gate.tick(isLocked: false, now: at(0))
        _ = gate.tick(isLocked: true, now: at(1))
        gate.propose(at: at(5))
        XCTAssertEqual(gate.tick(isLocked: true, now: at(15)), .fire)
        XCTAssertFalse(gate.acceptsProposal)

        gate.rearm()

        XCTAssertTrue(gate.acceptsProposal)
        XCTAssertEqual(gate.lockedSince, at(1))
        gate.propose(at: at(50))
        XCTAssertEqual(gate.tick(isLocked: true, now: at(60)), .fire)
    }

    func testRearmIgnoredOutsideASpentPeriod() {
        var gate = LockGraceGate(grace: 10)
        gate.rearm()
        XCTAssertEqual(gate.lockState, .unknown)

        _ = gate.tick(isLocked: true, now: at(0))
        gate.rearm()
        XCTAssertFalse(gate.acceptsProposal)

        _ = gate.tick(isLocked: false, now: at(1))
        gate.rearm()
        XCTAssertEqual(gate.lockState, .unlocked)
    }

    func testFireNowNeedsArmedPeriod() {
        var gate = LockGraceGate(grace: 0)
        XCTAssertFalse(gate.fireNow())

        _ = gate.tick(isLocked: true, now: at(0))
        XCTAssertFalse(gate.fireNow())

        _ = gate.tick(isLocked: false, now: at(1))
        XCTAssertFalse(gate.fireNow())
    }
}

// MARK: - Source Info

// @source-file: Source/Listeners/LockGraceGate.swift
