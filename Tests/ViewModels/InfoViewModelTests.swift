//
//  InfoViewModelTests.swift
//
//  Created on 03.01.2026.
//  Copyright © 2026 IGR Soft. All rights reserved.
//

import SwiftUI
import XCTest
@testable import Lock_Watcher

@MainActor
final class InfoViewModelTests: XCTestCase {
    private var sut: InfoViewModel!
    private var mockThiefManager: MockThiefManager!

    override func setUp() {
        super.setUp()
        mockThiefManager = MockThiefManager()
        mockThiefManager.stubbedDatabaseManager = MockDatabaseManager()
        sut = InfoViewModel(thiefManager: mockThiefManager)
    }

    override func tearDown() {
        sut = nil
        mockThiefManager = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertNotNil(sut.thiefManager)
    }

    // MARK: - Debug Trigger Tests

    func testDebugTriggerCallsThiefManager() async throws {
        mockThiefManager.stubbedDetectedTriggerResult = true

        sut.debugTrigger()

        // Give async task time to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        XCTAssertTrue(mockThiefManager.invokedDetectedTrigger)
        XCTAssertEqual(mockThiefManager.invokedDetectedTriggerCount, 1)
    }

    func testDebugTriggerMultipleCallsIncreasesCount() async throws {
        mockThiefManager.stubbedDetectedTriggerResult = true

        sut.debugTrigger()
        sut.debugTrigger()
        sut.debugTrigger()

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockThiefManager.invokedDetectedTriggerCount, 3)
    }

    // MARK: - Clean All Tests

    func testCleanAllCallsThiefManager() {
        sut.cleanAll()

        XCTAssertTrue(mockThiefManager.invokedCleanAll)
        XCTAssertEqual(mockThiefManager.invokedCleanAllCount, 1)
    }

    func testCleanAllMultipleCallsIncreasesCount() {
        sut.cleanAll()
        sut.cleanAll()
        sut.cleanAll()

        XCTAssertEqual(mockThiefManager.invokedCleanAllCount, 3)
    }

    // MARK: - Static Properties Tests

    func testLinkTextIsCorrect() {
        XCTAssertEqual(sut.linkText, "© Agnidia 2008 - 2026")
    }

    func testLinkUrlIsCorrect() {
        XCTAssertEqual(sut.linkUrl.absoluteString, "https://igrsoft.com")
    }

    // MARK: - ViewBuilder Tests

    func testDebugTitleReturnsText() {
        let text = sut.debugTitle()
        XCTAssertNotNil(text)
    }

    func testCleanTitleReturnsText() {
        let text = sut.cleanTitle()
        XCTAssertNotNil(text)
    }

    func testOpenSettingsTitleReturnsText() {
        let text = sut.openSettingsTitle()
        XCTAssertNotNil(text)
    }

    func testQuitAppTitleReturnsText() {
        let text = sut.quitAppTitle()
        XCTAssertNotNil(text)
    }
}
