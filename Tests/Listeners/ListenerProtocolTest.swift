//
//  ListenerProtocolTest.swift
//
//  Created on 28.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

@MainActor
final class ListenerTests: XCTestCase {
    var listener: MockListener!
    var dummyDTO: ThiefDto!

    override func setUpWithError() throws {
        listener = MockListener()
        dummyDTO = ThiefDto(triggerType: .setup)
    }

    override func tearDownWithError() throws {
        listener = nil
        dummyDTO = nil
    }

    func testListenerNameEnums() {
        XCTAssertEqual(ListenerName.onWakeUpListener.rawValue, 0)
        XCTAssertEqual(ListenerName.onWrongPassword.rawValue, 1)
        XCTAssertEqual(ListenerName.onBatteryPowerListener.rawValue, 2)
        XCTAssertEqual(ListenerName.onUSBConnectionListener.rawValue, 3)
        XCTAssertEqual(ListenerName.onLoginListener.rawValue, 4)
        XCTAssertEqual(ListenerName.onDisplayListener.rawValue, 5)
        XCTAssertEqual(ListenerName.onGeofenceListener.rawValue, 6)
        XCTAssertEqual(ListenerName.onLockedInputListener.rawValue, 7)
        XCTAssertEqual(ListenerName.allCases.count, 8)

        for name in ListenerName.allCases {
            switch name {
            case .onWakeUpListener:
                XCTAssertTrue(true)
            case .onWrongPassword:
                XCTAssertTrue(true)
            case .onBatteryPowerListener:
                XCTAssertTrue(true)
            case .onUSBConnectionListener:
                XCTAssertTrue(true)
            case .onLoginListener:
                XCTAssertTrue(true)
            case .onDisplayListener:
                XCTAssertTrue(true)
            case .onGeofenceListener:
                XCTAssertTrue(true)
            case .onLockedInputListener:
                XCTAssertTrue(true)
            }
        }
    }

    func testStartListener() {
        XCTAssertFalse(listener.isRunning)

        _ = listener.start()

        XCTAssertTrue(listener.isRunning)
    }

    func testStopListener() {
        _ = listener.start()
        XCTAssertTrue(listener.isRunning)

        listener.stop()

        XCTAssertFalse(listener.isRunning)
    }

    func testListenerAction() async {
        listener.stubbedStartResult = (.onWakeUpListener, .onWakeUp)

        let stream = listener.start()

        // Directly await the first event from the stream
        var eventReceived = false
        for await _ in stream {
            eventReceived = true
            break
        }

        XCTAssertTrue(eventReceived)
    }

    func testListenerReceivesCorrectEvent() async {
        listener.stubbedStartResult = (.onWakeUpListener, .onWakeUp)

        let stream = listener.start()

        // Directly await the first event from the stream
        var receivedEvent: ListenerName?
        for await (name, _) in stream {
            receivedEvent = name
            break
        }

        let expectedEvent = ListenerName.onWakeUpListener
        XCTAssertEqual(receivedEvent, expectedEvent)
    }
}

// MARK: - Source Info

// @source-file: Source/Listeners/BaseListenerProtocol.swift
