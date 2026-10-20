//
//  LockedInputListenerTests.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

/// @test-required
@MainActor
final class LockedInputListenerTests: XCTestCase {
    private var detector: MockLockDetector!
    private var clock: StubValue<Date>!
    private var idle: StubValue<TimeInterval>!
    private var sut: LockedInputListener!

    override func setUp() async throws {
        try await super.setUp()
        let clock = StubValue(Date(timeIntervalSince1970: 1_000_000))
        let idle = StubValue<TimeInterval>(1000)
        detector = MockLockDetector()
        self.clock = clock
        self.idle = idle
        sut = LockedInputListener(logger: LogMock(),
                                  lockDetector: detector,
                                  secondsSinceInput: { idle.value },
                                  now: { clock.value },
                                  grace: 10,
                                  lockStartWindow: 5)
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        detector = nil
        clock = nil
        idle = nil
        try await super.tearDown()
    }

    /// Advances the wall clock and the idle counter together, as while awake.
    private func tick(_ locked: Bool, after seconds: TimeInterval = 1) {
        clock.value = clock.value.addingTimeInterval(seconds)
        idle.value += seconds
        detector.tick(locked: locked)
    }

    private func input() {
        idle.value = 0
    }

    private func finish(_ stream: AsyncStream<ListenerEvent>) async -> [TriggerType] {
        sut.stop()
        return await collectTriggers(stream)
    }

    /// Locks at t+1 and returns once the lock-start window has passed.
    private func lockPastStartWindow() {
        tick(false)
        tick(true)
        tick(true, after: 6)
    }

    func testInputAfterStartWindowFiresWhenLockHolds() async {
        let stream = sut.start()
        lockPastStartWindow()
        input()
        for _ in 0 ..< 11 {
            tick(true)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [.lockedInput])
    }

    func testFiresOncePerLockPeriod() async {
        let stream = sut.start()
        lockPastStartWindow()
        input()
        tick(true)
        tick(true, after: 11)
        input()
        tick(true)
        tick(true, after: 11)

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [.lockedInput])
    }

    func testZeroDelayFiresOnNextLockedTick() async {
        let idle: StubValue<TimeInterval> = self.idle
        let clock: StubValue<Date> = self.clock
        let detector: MockLockDetector = detector
        let makeListener = {
            LockedInputListener(logger: LogMock(), lockDetector: detector, secondsSinceInput: { idle.value }, now: { clock.value }, grace: 0, lockStartWindow: 5)
        }

        let listener = makeListener()
        let stream = listener.start()
        lockPastStartWindow()
        input()
        tick(true)
        listener.stop()
        let afterDetection = await collectTriggers(stream)
        XCTAssertEqual(afterDetection, [])

        let second = makeListener()
        let secondStream = second.start()
        lockPastStartWindow()
        input()
        tick(true)
        tick(true)
        second.stop()
        let triggers = await collectTriggers(secondStream)
        XCTAssertEqual(triggers, [.lockedInput])
    }

    // MARK: - Re-arm after cooldown

    /// Locks, gives one input, and ticks until the 10 s delay fires.
    private func fireOnce() {
        lockPastStartWindow()
        input()
        for _ in 0 ..< 11 {
            tick(true)
        }
    }

    func testSecondInputAfterCooldownFiresAgain() async {
        let stream = sut.start()
        fireOnce()
        for _ in 0 ..< 31 {
            tick(true)
        }
        input()
        for _ in 0 ..< 11 {
            tick(true)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [.lockedInput, .lockedInput])
    }

    func testInputDuringCooldownNeverFires() async {
        let stream = sut.start()
        fireOnce()
        for _ in 0 ..< 5 {
            tick(true)
        }
        input()
        for _ in 0 ..< 60 {
            tick(true)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [.lockedInput])
    }

    func testOneInputFiresOnceAcrossALongLock() async {
        let stream = sut.start()
        fireOnce()
        for _ in 0 ..< 120 {
            tick(true)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [.lockedInput])
    }

    func testUnlockDuringCooldownStartsFresh() async {
        let stream = sut.start()
        fireOnce()
        tick(true)
        tick(false)
        tick(true)
        tick(true)
        input()
        tick(true)
        tick(true, after: 6)
        input()
        for _ in 0 ..< 11 {
            tick(true)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [.lockedInput, .lockedInput])
    }

    func testWakeFromSleepWithoutInputYieldsNothing() async {
        let stream = sut.start()
        lockPastStartWindow()

        // System sleep: the wall clock jumps, the HID idle counter does not.
        clock.value = clock.value.addingTimeInterval(15 * 3600)
        for _ in 0 ..< 15 {
            tick(true)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testInputInsideStartWindowYieldsNothing() async {
        let stream = sut.start()
        tick(false)
        tick(true)
        tick(true, after: 2)
        input()
        for _ in 0 ..< 15 {
            tick(true)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testInputFollowedByUnlockInsideGraceYieldsNothing() async {
        let stream = sut.start()
        lockPastStartWindow()
        input()
        tick(true)
        tick(true, after: 3)
        tick(false)
        tick(false, after: 20)

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testInputWhileUnlockedYieldsNothing() async {
        let stream = sut.start()
        tick(false)
        input()
        for _ in 0 ..< 15 {
            tick(false)
        }

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testStartedMidLockStaysSilent() async {
        let stream = sut.start()
        tick(true)
        tick(true, after: 6)
        input()
        tick(true)
        tick(true, after: 11)

        let triggers = await finish(stream)
        XCTAssertEqual(triggers, [])
    }

    func testStartIsIdempotentAndStopEndsRunning() {
        _ = sut.start()
        _ = sut.start()
        XCTAssertTrue(sut.isRunning)
        sut.stop()
        XCTAssertFalse(sut.isRunning)
    }
}

// MARK: - Source Info

// @source-file: Source/Listeners/LockedInputListener.swift
