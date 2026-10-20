//
//  ThiefDtoTest.swift
//
//  Created on 01.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import CoreLocation
import XCTest
@testable import Lock_Watcher

final class TriggerTypeTests: XCTestCase {
    // MARK: - TriggerType Tests

    func testTriggerTypeRawValues() {
        XCTAssertEqual(TriggerType.setup.rawValue, "setup")
        XCTAssertEqual(TriggerType.onWakeUp.rawValue, "onWakeUp")
        XCTAssertEqual(TriggerType.onWrongPassword.rawValue, "onWrongPassword")
        XCTAssertEqual(TriggerType.onBatteryPower.rawValue, "onBatteryPower")
        XCTAssertEqual(TriggerType.usbConnected.rawValue, "usbConnected")
        XCTAssertEqual(TriggerType.logedIn.rawValue, "logedIn")
        XCTAssertEqual(TriggerType.debug.rawValue, "debug")
    }

    func testTriggerTypeNameLocalization() {
        // Test that name property returns localized string (not crashing)
        let types: [TriggerType] = [.setup, .onWakeUp, .onWrongPassword, .onBatteryPower, .usbConnected, .logedIn, .debug]
        for type in types {
            XCTAssertFalse(type.name.isEmpty, "Name should not be empty for \(type)")
        }
    }

    func testTriggerTypeSendable() {
        // TriggerType should be Sendable
        let type: TriggerType = .onWakeUp
        Task {
            let capturedType = type
            XCTAssertEqual(capturedType, .onWakeUp)
        }
    }
}

final class ThiefDtoTests: XCTestCase {
    // MARK: - Initialization Tests

    func testThiefDtoInitWithMinimalParameters() {
        let dto = ThiefDto(triggerType: .setup)

        XCTAssertEqual(dto.triggerType, .setup)
        XCTAssertNil(dto.coordinate)
        XCTAssertNil(dto.ipAddress)
        XCTAssertNil(dto.traceRoute)
        XCTAssertNil(dto.snapshot)
        XCTAssertNil(dto.filePath)
        XCTAssertNotNil(dto.date)
    }

    func testThiefDtoInitWithAllParameters() {
        let testDate = Date()
        let testCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let testURL = URL(fileURLWithPath: "/tmp/test.jpg")

        let dto = ThiefDto(
            triggerType: .onWakeUp,
            coordinate: testCoordinate,
            ipAddress: "192.168.1.1",
            traceRoute: "hop 1: 192.168.1.1",
            snapshot: nil,
            filePath: testURL,
            date: testDate
        )

        XCTAssertEqual(dto.triggerType, .onWakeUp)
        XCTAssertEqual(dto.coordinate?.latitude, 37.7749)
        XCTAssertEqual(dto.coordinate?.longitude, -122.4194)
        XCTAssertEqual(dto.ipAddress, "192.168.1.1")
        XCTAssertEqual(dto.traceRoute, "hop 1: 192.168.1.1")
        XCTAssertEqual(dto.filePath, testURL)
        XCTAssertEqual(dto.date, testDate)
    }

    // MARK: - Equatable Tests

    func testThiefDtoEquality_SameDate() {
        let date = Date()
        let dto1 = ThiefDto(triggerType: .setup, date: date)
        let dto2 = ThiefDto(triggerType: .onWakeUp, date: date)

        XCTAssertEqual(dto1, dto2, "ThiefDto equality is based on date only")
    }

    func testThiefDtoEquality_DifferentDate() {
        let dto1 = ThiefDto(triggerType: .setup, date: Date())
        let dto2 = ThiefDto(triggerType: .setup, date: Date().addingTimeInterval(1))

        XCTAssertNotEqual(dto1, dto2)
    }

    // MARK: - Description Tests

    func testDescriptionWithNoOptionalData() {
        let dto = ThiefDto(triggerType: .setup)

        XCTAssertEqual(dto.description(), "")
    }

    func testDescriptionWithIPAddress() {
        let dto = ThiefDto(triggerType: .setup, ipAddress: "192.168.1.1")

        XCTAssertEqual(dto.description(), "ip: 192.168.1.1")
    }

    func testDescriptionWithTraceRoute() {
        let dto = ThiefDto(triggerType: .setup, traceRoute: "traceroute data")

        XCTAssertEqual(dto.description(), "traceroute data")
    }

    func testDescriptionWithIPAddressAndTraceRoute() {
        let dto = ThiefDto(triggerType: .setup, ipAddress: "10.0.0.1", traceRoute: "route info")

        let description = dto.description()
        XCTAssertTrue(description.contains("ip: 10.0.0.1"))
        XCTAssertTrue(description.contains("route info"))
    }

    func testDescriptionWithCoordinate() {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let dto = ThiefDto(triggerType: .setup, coordinate: coordinate)

        let description = dto.description()
        XCTAssertFalse(description.isEmpty)
    }

    func testDescriptionWithAllData() {
        let coordinate = CLLocationCoordinate2D(latitude: 50.0, longitude: 30.0)
        let dto = ThiefDto(
            triggerType: .setup,
            coordinate: coordinate,
            ipAddress: "8.8.8.8",
            traceRoute: "hop1\nhop2"
        )

        let description = dto.description()
        XCTAssertTrue(description.contains("ip: 8.8.8.8"))
        XCTAssertTrue(description.contains("hop1\nhop2"))
    }

    // MARK: - Sendable Tests

    func testThiefDtoIsSendable() {
        let dto = ThiefDto(triggerType: .onWakeUp)

        Task {
            let capturedDto = dto
            XCTAssertEqual(capturedDto.triggerType, .onWakeUp)
        }
    }

    // MARK: - Media Tests

    func testPhotoRecordMedia() {
        let still = URL(fileURLWithPath: "/tmp/a.jpeg")
        let dto = ThiefDto(triggerType: .onWakeUp, filePath: still)

        XCTAssertNil(dto.videoURL)
        XCTAssertEqual(dto.media, .photo(still: still))
    }

    func testVideoRecordMediaKeepsPosterAsStill() {
        let movie = URL(fileURLWithPath: "/tmp/a.mov")
        let poster = URL(fileURLWithPath: "/tmp/a.jpeg")
        let dto = ThiefDto(triggerType: .onWakeUp, filePath: poster, videoURL: movie)

        XCTAssertEqual(dto.videoURL, movie)
        XCTAssertEqual(dto.media, .video(movie: movie, poster: poster))
    }

    func testRecordWithoutFilesHasNoMedia() {
        XCTAssertNil(ThiefDto(triggerType: .onWakeUp).media)
    }

    func testEqualityStillComparesDateOnly() {
        let date = Date()
        let photo = ThiefDto(triggerType: .onWakeUp, date: date)
        let video = ThiefDto(triggerType: .logedIn, videoURL: URL(fileURLWithPath: "/tmp/a.mov"), date: date)

        XCTAssertEqual(photo, video)
    }

    // MARK: - DatabaseDto Tests

    func testDatabaseDtoForVideoUsesMoviePathAndPosterData() throws {
        let movie = URL(fileURLWithPath: "/tmp/a.mov")
        let dto = ThiefDto(triggerType: .onWakeUp, snapshot: .testImage(), filePath: URL(fileURLWithPath: "/tmp/a.jpeg"), videoURL: movie)

        let record = try XCTUnwrap(DatabaseDto(with: dto))

        XCTAssertEqual(record.path, movie)
        XCTAssertFalse(record.data.isEmpty)
    }

    func testDatabaseDtoIsNilWithoutStill() {
        let dto = ThiefDto(triggerType: .onWakeUp, videoURL: URL(fileURLWithPath: "/tmp/a.mov"))

        XCTAssertNil(DatabaseDto(with: dto))
    }
}
