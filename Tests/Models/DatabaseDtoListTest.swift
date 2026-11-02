//
//  DatabaseDtoListTest.swift
//
//  Created on 01.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import XCTest
@testable import Lock_Watcher

final class DatabaseDtoTests: XCTestCase {
    // MARK: - Initialization Tests

    func testDatabaseDtoInitWithThiefDto() throws {
        let testDate = Date()
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        let testURL = URL(fileURLWithPath: "/tmp/test.jpg")

        let thiefDto = ThiefDto(
            triggerType: .onWakeUp,
            snapshot: testImage,
            filePath: testURL,
            date: testDate
        )

        let databaseDto = try XCTUnwrap(DatabaseDto(with: thiefDto))

        XCTAssertEqual(databaseDto.date, testDate)
        XCTAssertEqual(databaseDto.path, testURL)
        XCTAssertNotNil(databaseDto.data)
    }

    // MARK: - Codable Tests

    func testDatabaseDtoCodable() throws {
        let testDate = Date()
        let testImage = NSImage(size: NSSize(width: 50, height: 50))
        let testURL = URL(fileURLWithPath: "/tmp/codable_test.jpg")

        let thiefDto = ThiefDto(
            triggerType: .setup,
            snapshot: testImage,
            filePath: testURL,
            date: testDate
        )

        let originalDto = try XCTUnwrap(DatabaseDto(with: thiefDto))

        // Encode
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalDto)

        // Decode
        let decoder = JSONDecoder()
        let decodedDto = try decoder.decode(DatabaseDto.self, from: encodedData)

        XCTAssertEqual(originalDto.date, decodedDto.date)
        XCTAssertEqual(originalDto.data, decodedDto.data)
        XCTAssertEqual(originalDto.path, decodedDto.path)
    }

    func testDatabaseDtoCodableWithoutPath() throws {
        let testDate = Date()
        let testImage = NSImage(size: NSSize(width: 50, height: 50))

        let thiefDto = ThiefDto(
            triggerType: .debug,
            snapshot: testImage,
            date: testDate
        )

        let originalDto = try XCTUnwrap(DatabaseDto(with: thiefDto))

        // Encode
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalDto)

        // Decode
        let decoder = JSONDecoder()
        let decodedDto = try decoder.decode(DatabaseDto.self, from: encodedData)

        XCTAssertEqual(originalDto.date, decodedDto.date)
        XCTAssertNil(decodedDto.path)
    }

    // MARK: - Equatable Tests

    func testDatabaseDtoEquality_Equal() throws {
        let testDate = Date()
        let testImage = NSImage(size: NSSize(width: 50, height: 50))
        let testURL = URL(fileURLWithPath: "/tmp/equality_test.jpg")

        let thiefDto1 = ThiefDto(triggerType: .setup, snapshot: testImage, filePath: testURL, date: testDate)
        let thiefDto2 = ThiefDto(triggerType: .setup, snapshot: testImage, filePath: testURL, date: testDate)

        let dto1 = try XCTUnwrap(DatabaseDto(with: thiefDto1))
        let dto2 = try XCTUnwrap(DatabaseDto(with: thiefDto2))

        XCTAssertEqual(dto1, dto2)
    }

    func testDatabaseDtoEquality_DifferentDate() throws {
        let testImage = NSImage(size: NSSize(width: 50, height: 50))

        let thiefDto1 = ThiefDto(triggerType: .setup, snapshot: testImage, date: Date())
        let thiefDto2 = ThiefDto(triggerType: .setup, snapshot: testImage, date: Date().addingTimeInterval(1))

        let dto1 = try XCTUnwrap(DatabaseDto(with: thiefDto1))
        let dto2 = try XCTUnwrap(DatabaseDto(with: thiefDto2))

        XCTAssertNotEqual(dto1, dto2)
    }

    func testDatabaseDtoEquality_DifferentPath() throws {
        let testDate = Date()
        let testImage = NSImage(size: NSSize(width: 50, height: 50))

        let thiefDto1 = ThiefDto(triggerType: .setup, snapshot: testImage, filePath: URL(fileURLWithPath: "/tmp/path1.jpg"), date: testDate)
        let thiefDto2 = ThiefDto(triggerType: .setup, snapshot: testImage, filePath: URL(fileURLWithPath: "/tmp/path2.jpg"), date: testDate)

        let dto1 = try XCTUnwrap(DatabaseDto(with: thiefDto1))
        let dto2 = try XCTUnwrap(DatabaseDto(with: thiefDto2))

        XCTAssertNotEqual(dto1, dto2)
    }

    // MARK: - Comparable Tests

    func testDatabaseDtoLessThan() throws {
        let testImage = NSImage(size: NSSize(width: 50, height: 50))
        let earlierDate = Date()
        let laterDate = earlierDate.addingTimeInterval(60)

        let thiefDto1 = ThiefDto(triggerType: .setup, snapshot: testImage, date: earlierDate)
        let thiefDto2 = ThiefDto(triggerType: .setup, snapshot: testImage, date: laterDate)

        let dto1 = try XCTUnwrap(DatabaseDto(with: thiefDto1))
        let dto2 = try XCTUnwrap(DatabaseDto(with: thiefDto2))

        XCTAssertTrue(dto1 < dto2)
        XCTAssertFalse(dto2 < dto1)
    }

    // MARK: - Hashable Tests

    func testDatabaseDtoHashable() throws {
        let testDate = Date()
        let testImage = NSImage(size: NSSize(width: 50, height: 50))

        let thiefDto1 = ThiefDto(triggerType: .setup, snapshot: testImage, date: testDate)
        let thiefDto2 = ThiefDto(triggerType: .setup, snapshot: testImage, date: testDate)

        let dto1 = try XCTUnwrap(DatabaseDto(with: thiefDto1))
        let dto2 = try XCTUnwrap(DatabaseDto(with: thiefDto2))

        var set = Set<DatabaseDto>()
        set.insert(dto1)
        set.insert(dto2)

        // Both should have same hash since same date and data
        XCTAssertEqual(dto1.hashValue, dto2.hashValue)
    }

    // MARK: - Identifiable Tests

    func testDatabaseDtoIdentifiable() throws {
        let testImage = NSImage(size: NSSize(width: 50, height: 50))
        let thiefDto = ThiefDto(triggerType: .setup, snapshot: testImage)

        let dto = try XCTUnwrap(DatabaseDto(with: thiefDto))

        // id should exist (default to ObjectIdentifier for classes without explicit id)
        _ = dto.id
    }
}

@MainActor
final class DatabaseDtoListTests: XCTestCase {
    // MARK: - Initialization Tests

    func testDatabaseDtoListInitWithEmptyArray() {
        let list = DatabaseDtoList(dtos: [])

        XCTAssertTrue(list.dtos.isEmpty)
    }

    func testDatabaseDtoListInitWithDtos() throws {
        let testImage = NSImage(size: NSSize(width: 50, height: 50))
        let thiefDto1 = ThiefDto(triggerType: .setup, snapshot: testImage)
        let thiefDto2 = ThiefDto(triggerType: .onWakeUp, snapshot: testImage)

        let dto1 = try XCTUnwrap(DatabaseDto(with: thiefDto1))
        let dto2 = try XCTUnwrap(DatabaseDto(with: thiefDto2))

        let list = DatabaseDtoList(dtos: [dto1, dto2])

        XCTAssertEqual(list.dtos.count, 2)
    }

    // MARK: - Append Tests

    func testDatabaseDtoListAppend() throws {
        let list = DatabaseDtoList(dtos: [])

        let testImage = NSImage(size: NSSize(width: 50, height: 50))
        let thiefDto = ThiefDto(triggerType: .setup, snapshot: testImage)
        let dto = try XCTUnwrap(DatabaseDto(with: thiefDto))

        list.append(dto)

        XCTAssertEqual(list.dtos.count, 1)
        XCTAssertEqual(list.dtos.first, dto)
    }

    func testDatabaseDtoListAppendMultiple() throws {
        let list = DatabaseDtoList(dtos: [])

        let testImage = NSImage(size: NSSize(width: 50, height: 50))

        for i in 0 ..< 5 {
            let thiefDto = ThiefDto(triggerType: .setup, snapshot: testImage, date: Date().addingTimeInterval(Double(i)))
            let dto = try XCTUnwrap(DatabaseDto(with: thiefDto))
            list.append(dto)
        }

        XCTAssertEqual(list.dtos.count, 5)
    }

    // MARK: - Empty Static Property Tests

    func testDatabaseDtoListEmpty() {
        let emptyList = DatabaseDtoList.empty

        XCTAssertTrue(emptyList.dtos.isEmpty)
    }

    // MARK: - Codable Tests

    func testDatabaseDtoListCodable() throws {
        let testImage = NSImage(size: NSSize(width: 50, height: 50))
        let thiefDto1 = ThiefDto(triggerType: .setup, snapshot: testImage, date: Date())
        let thiefDto2 = ThiefDto(triggerType: .onWakeUp, snapshot: testImage, date: Date().addingTimeInterval(1))

        let dto1 = try XCTUnwrap(DatabaseDto(with: thiefDto1))
        let dto2 = try XCTUnwrap(DatabaseDto(with: thiefDto2))

        let originalList = DatabaseDtoList(dtos: [dto1, dto2])

        // Encode
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalList)

        // Decode
        let decoder = JSONDecoder()
        let decodedList = try decoder.decode(DatabaseDtoList.self, from: encodedData)

        XCTAssertEqual(decodedList.dtos.count, 2)
        XCTAssertEqual(decodedList.dtos[0].date, dto1.date)
        XCTAssertEqual(decodedList.dtos[1].date, dto2.date)
    }

    func testDatabaseDtoListCodableEmpty() throws {
        let originalList = DatabaseDtoList.empty

        // Encode
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalList)

        // Decode
        let decoder = JSONDecoder()
        let decodedList = try decoder.decode(DatabaseDtoList.self, from: encodedData)

        XCTAssertTrue(decodedList.dtos.isEmpty)
    }

    // MARK: - ObservableObject Tests

    func testDatabaseDtoListIsObservableObject() throws {
        let list = DatabaseDtoList.empty

        // Verify @Published property exists and can be observed
        let expectation = expectation(description: "Published value should change")
        expectation.isInverted = true // We just verify no crash occurs

        let testImage = NSImage(size: NSSize(width: 50, height: 50))
        let thiefDto = ThiefDto(triggerType: .setup, snapshot: testImage)
        let dto = try XCTUnwrap(DatabaseDto(with: thiefDto))

        list.append(dto)

        waitForExpectations(timeout: 0.1)
        XCTAssertEqual(list.dtos.count, 1)
    }
}
