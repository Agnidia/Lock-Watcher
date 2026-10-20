//
//  LastThiefDetectionViewModelTests.swift
//
//  Created on 03.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import Combine
import XCTest
@testable import Lock_Watcher

@MainActor
final class LastThiefDetectionViewModelTests: XCTestCase {
    private var sut: LastThiefDetectionViewModel!
    private var mockDatabaseManager: MockDatabaseManager!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        mockDatabaseManager = MockDatabaseManager()
        mockDatabaseManager.stubbedRemoveResult = DatabaseDtoList.empty
        sut = LastThiefDetectionViewModel(databaseManager: mockDatabaseManager)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        mockDatabaseManager = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestDatabaseDto(date: Date = Date()) -> DatabaseDto {
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        let thiefDto = ThiefDto(triggerType: .debug, snapshot: testImage, date: date)
        return DatabaseDto(with: thiefDto)!
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertNotNil(sut.databaseManager)
    }

    func testInitialLatestImagesIsEmpty() {
        XCTAssertTrue(sut.latestImages.isEmpty)
    }

    func testInitialSelectedItemIsNil() {
        XCTAssertNil(sut.selectedItem)
    }

    // MARK: - Publisher Tests

    func testLatestImagesPublisherUpdatesLatestImages() {
        let dto1 = createTestDatabaseDto(date: Date())
        let dto2 = createTestDatabaseDto(date: Date().addingTimeInterval(1))

        mockDatabaseManager.stubbedLatestImages = [dto1, dto2]

        // Allow publisher to propagate
        let expectation = expectation(description: "Wait for publisher")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.1)

        XCTAssertEqual(sut.latestImages.count, 2)
    }

    func testLatestImagesAreSortedByDateDescending() {
        let olderDate = Date().addingTimeInterval(-100)
        let newerDate = Date()

        let olderDto = createTestDatabaseDto(date: olderDate)
        let newerDto = createTestDatabaseDto(date: newerDate)

        // Publish in ascending order
        mockDatabaseManager.stubbedLatestImages = [olderDto, newerDto]

        let expectation = expectation(description: "Wait for publisher")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.1)

        // Should be sorted descending (newest first)
        XCTAssertEqual(sut.latestImages.count, 2)
        if sut.latestImages.count == 2 {
            XCTAssertTrue(sut.latestImages[0].date > sut.latestImages[1].date)
        }
    }

    func testSelectedItemIsSetToFirstAfterUpdate() {
        let dto1 = createTestDatabaseDto(date: Date())
        let dto2 = createTestDatabaseDto(date: Date().addingTimeInterval(-10))

        mockDatabaseManager.stubbedLatestImages = [dto1, dto2]

        let expectation = expectation(description: "Wait for publisher")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.1)

        // First item (newest) should be selected
        XCTAssertNotNil(sut.selectedItem)
        XCTAssertEqual(sut.selectedItem, sut.latestImages.first)
    }

    // MARK: - Remove Tests

    func testRemoveCallsDatabaseManager() {
        let dto = createTestDatabaseDto()
        mockDatabaseManager.stubbedRemoveResult = DatabaseDtoList(dtos: [])

        sut.remove(dto)

        XCTAssertTrue(mockDatabaseManager.invokedRemove)
        XCTAssertEqual(mockDatabaseManager.invokedRemoveCount, 1)
    }

    func testRemovePassesCorrectDto() {
        let dto = createTestDatabaseDto()
        mockDatabaseManager.stubbedRemoveResult = DatabaseDtoList(dtos: [])

        sut.remove(dto)

        XCTAssertEqual(mockDatabaseManager.invokedRemoveParameters?.dto, dto)
    }

    func testRemoveUpdatesLatestImagesFromResult() {
        let dto1 = createTestDatabaseDto(date: Date())
        let dto2 = createTestDatabaseDto(date: Date().addingTimeInterval(1))

        // Initially set two items
        mockDatabaseManager.stubbedLatestImages = [dto1, dto2]

        let expectation = expectation(description: "Wait for initial setup")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.1)

        // Remove should return only dto2
        mockDatabaseManager.stubbedRemoveResult = DatabaseDtoList(dtos: [dto2])

        sut.remove(dto1)

        XCTAssertEqual(sut.latestImages.count, 1)
        XCTAssertEqual(sut.latestImages.first, dto2)
    }

    func testRemoveAllItemsClearsLatestImages() {
        let dto = createTestDatabaseDto()

        mockDatabaseManager.stubbedLatestImages = [dto]

        let expectation = expectation(description: "Wait for initial setup")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.1)

        mockDatabaseManager.stubbedRemoveResult = DatabaseDtoList(dtos: [])

        sut.remove(dto)

        XCTAssertTrue(sut.latestImages.isEmpty)
        XCTAssertNil(sut.selectedItem)
    }

    // MARK: - Selected Item Tests

    func testSelectedItemCanBeChanged() {
        let dto1 = createTestDatabaseDto(date: Date())
        let dto2 = createTestDatabaseDto(date: Date().addingTimeInterval(-10))

        mockDatabaseManager.stubbedLatestImages = [dto1, dto2]

        let expectation = expectation(description: "Wait for publisher")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.1)

        // Change selected item
        sut.selectedItem = sut.latestImages.last

        XCTAssertEqual(sut.selectedItem, sut.latestImages.last)
    }

    func testSelectedItemCanBeSetToNil() {
        let dto = createTestDatabaseDto()

        mockDatabaseManager.stubbedLatestImages = [dto]

        let expectation = expectation(description: "Wait for publisher")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.1)

        sut.selectedItem = nil

        XCTAssertNil(sut.selectedItem)
    }

    // MARK: - Multiple Operations Tests

    func testMultipleRemoveOperations() {
        let dto1 = createTestDatabaseDto(date: Date())
        let dto2 = createTestDatabaseDto(date: Date().addingTimeInterval(1))
        let dto3 = createTestDatabaseDto(date: Date().addingTimeInterval(2))

        mockDatabaseManager.stubbedLatestImages = [dto1, dto2, dto3]

        let expectation = expectation(description: "Wait for initial setup")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.1)

        // Remove first item
        mockDatabaseManager.stubbedRemoveResult = DatabaseDtoList(dtos: [dto2, dto3])
        sut.remove(dto1)
        XCTAssertEqual(sut.latestImages.count, 2)

        // Remove second item
        mockDatabaseManager.stubbedRemoveResult = DatabaseDtoList(dtos: [dto3])
        sut.remove(dto2)
        XCTAssertEqual(sut.latestImages.count, 1)

        XCTAssertEqual(mockDatabaseManager.invokedRemoveCount, 2)
    }
}
