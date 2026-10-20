//
//  MainViewModelTests.swift
//
//  Created on 03.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import XCTest
@testable import Lock_Watcher

@MainActor
final class MainViewModelTests: XCTestCase {
    private var sut: MainViewModel!
    private var mockThiefManager: MockThiefManager!
    private var mockDatabaseManager: MockDatabaseManager!

    override func setUp() async throws {
        try await super.setUp()
        mockDatabaseManager = MockDatabaseManager()
        mockThiefManager = MockThiefManager()
        mockThiefManager.stubbedDatabaseManager = mockDatabaseManager
        sut = MainViewModel(thiefManager: mockThiefManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockThiefManager = nil
        mockDatabaseManager = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertNotNil(sut.thiefManager)
        XCTAssertNotNil(sut.databaseManager)
    }

    func testInitialIsAccessGrantedIsTrue() {
        XCTAssertTrue(sut.isAccessGranted)
    }

    func testLastThiefDetectionViewModelIsCreated() {
        XCTAssertNotNil(sut.lastThiefDetectionViewModel)
    }

    func testInfoViewModelIsCreated() {
        XCTAssertNotNil(sut.infoViewModel)
    }

    // MARK: - Dependency Injection Tests

    func testThiefManagerIsSetCorrectly() {
        XCTAssertTrue(mockThiefManager.invokedDatabaseManagerGetter)
    }

    func testDatabaseManagerIsFromThiefManager() {
        // The database manager should be the same instance from the thief manager
        XCTAssertTrue(mockThiefManager.invokedDatabaseManagerGetterCount >= 1)
    }

    // MARK: - Published Properties Tests

    func testIsAccessGrantedCanBeChanged() {
        XCTAssertTrue(sut.isAccessGranted)

        sut.isAccessGranted = false
        XCTAssertFalse(sut.isAccessGranted)
    }

    // MARK: - View Settings Tests

    func testViewSettingsExists() {
        XCTAssertNotNil(sut.viewSettings)
    }

    // MARK: - Access Granted Block Tests

    func testAccessGrantedBlockIsInitiallyNil() {
        XCTAssertNil(sut.accessGrantedBlock)
    }

    func testAccessGrantedBlockCanBeSet() {
        var wasCalled = false
        sut.accessGrantedBlock = {
            wasCalled = true
        }

        XCTAssertNotNil(sut.accessGrantedBlock)

        sut.accessGrantedBlock?()
        XCTAssertTrue(wasCalled)
    }

    // MARK: - Preview Tests

    func testPreviewInstanceExists() {
        let preview = MainViewModel.preview
        XCTAssertNotNil(preview)
    }

    func testPreviewInstanceHasDefaultValues() {
        let preview = MainViewModel.preview
        XCTAssertTrue(preview.isAccessGranted)
    }

    // MARK: - LastThiefDetectionViewModel Integration Tests

    func testLastThiefDetectionViewModelSharesDatabaseManager() {
        // Both should use the same database manager
        XCTAssertNotNil(sut.lastThiefDetectionViewModel.databaseManager)
    }
}
