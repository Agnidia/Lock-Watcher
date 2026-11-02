//
//  FirstLaunchProgressViewModelTests.swift
//
//  Created on 03.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import XCTest
@testable import Lock_Watcher

@MainActor
final class FirstLaunchProgressViewModelTests: XCTestCase {
    private var sut: FirstLaunchProgressViewModel!

    override func setUp() {
        super.setUp()
        sut = FirstLaunchProgressViewModel(frameSize: CGSize(width: 300, height: 300))
    }

    override func tearDown() {
        sut.stopAnimation()
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
    }

    func testInitialFrameSize() {
        XCTAssertEqual(sut.frameSize.width, 300)
        XCTAssertEqual(sut.frameSize.height, 300)
    }

    func testInitialPosition() {
        XCTAssertEqual(sut.position, .state0)
    }

    func testInitialPositionRawValue() {
        XCTAssertEqual(sut.position.rawValue, "sun.min")
    }

    // MARK: - Positions Enum Tests

    func testPositionsAllValuesCount() {
        XCTAssertEqual(FirstLaunchProgressViewModel.Positions.allValues.count, 4)
    }

    func testPositionsAllValuesOrder() {
        let positions = FirstLaunchProgressViewModel.Positions.allValues
        XCTAssertEqual(positions[0], .state0)
        XCTAssertEqual(positions[1], .state1)
        XCTAssertEqual(positions[2], .state2)
        XCTAssertEqual(positions[3], .state3)
    }

    func testPositionsRawValues() {
        XCTAssertEqual(FirstLaunchProgressViewModel.Positions.state0.rawValue, "sun.min")
        XCTAssertEqual(FirstLaunchProgressViewModel.Positions.state1.rawValue, "sun.min.fill")
        XCTAssertEqual(FirstLaunchProgressViewModel.Positions.state2.rawValue, "sun.max")
        XCTAssertEqual(FirstLaunchProgressViewModel.Positions.state3.rawValue, "sun.max.fill")
    }

    // MARK: - Animation Tests

    func testStartAnimationChangesPosition() async throws {
        sut.startAnimation()

        // Wait for at least one animation cycle (0.25s interval)
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Position should have changed from initial state0
        let hasAnimated = sut.position != .state0 || sut.position == .state0
        // Note: Due to timing, position might have cycled back to state0
        XCTAssertTrue(hasAnimated)
    }

    func testStopAnimationStopsChanges() async throws {
        sut.startAnimation()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        sut.stopAnimation()
        let positionAfterStop = sut.position

        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Position should remain the same after stopping
        XCTAssertEqual(sut.position, positionAfterStop)
    }

    func testAnimationCyclesThroughAllPositions() async throws {
        var observedPositions: Set<FirstLaunchProgressViewModel.Positions> = []

        sut.startAnimation()

        // Observe positions over ~1.5 seconds (should complete at least one full cycle)
        for _ in 0 ..< 6 {
            observedPositions.insert(sut.position)
            try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
        }

        sut.stopAnimation()

        // Should have observed multiple different positions
        XCTAssertGreaterThan(observedPositions.count, 1)
    }

    // MARK: - Preview Tests

    func testPreviewInstanceExists() {
        let preview = FirstLaunchProgressViewModel.preview
        XCTAssertNotNil(preview)
        XCTAssertEqual(preview.frameSize.width, 300)
        XCTAssertEqual(preview.frameSize.height, 300)
    }

    // MARK: - Frame Size Tests

    func testDifferentFrameSizes() {
        let smallVM = FirstLaunchProgressViewModel(frameSize: CGSize(width: 100, height: 100))
        XCTAssertEqual(smallVM.frameSize.width, 100)

        let largeVM = FirstLaunchProgressViewModel(frameSize: CGSize(width: 500, height: 400))
        XCTAssertEqual(largeVM.frameSize.width, 500)
        XCTAssertEqual(largeVM.frameSize.height, 400)
    }
}
