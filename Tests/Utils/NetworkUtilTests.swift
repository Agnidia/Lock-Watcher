//
//  NetworkUtilTests.swift
//
//  Created on 30.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

final class NetworkUtilTests: XCTestCase {
    nonisolated(unsafe) var networkUtil: NetworkUtilProtocol!
    nonisolated(unsafe) var mockLogger: LogMock!

    override func setUp() {
        super.setUp()
        mockLogger = LogMock()
        networkUtil = NetworkUtil(logger: mockLogger)
    }

    override func tearDown() {
        mockLogger = nil
        networkUtil = nil
        super.tearDown()
    }

    /// Test local network interface addresses (does not require network)
    func testGetIFAddresses() {
        let ipAddress = networkUtil.getIFAddresses()

        XCTAssertFalse(ipAddress.isEmpty, "The IP Address should be not empty")
        XCTAssertNil(mockLogger.errorMessage, "No error log should be generated when fetching IP Address successfully.")
    }

    func testGetTraceRoute_success() {
        let host = "8.8.8.8"
        let testExpectation = expectation(description: "Expecting trace route to complete")

        networkUtil.getTraceRoute(host: host) { traceRoute in
            XCTAssertTrue(traceRoute.contains(host), "Trace route result should contain \(host)")
            testExpectation.fulfill()
        }

        wait(for: [testExpectation], timeout: 10)
    }

    func testGetTraceRoute_failed() {
        let host = "8.8.8.8.8"
        let testExpectation = expectation(description: "Expecting trace route to complete")

        networkUtil.getTraceRoute(host: host) { traceRoute in
            XCTAssertFalse(traceRoute.contains(host), "Trace route result should not contain invalid host")
            testExpectation.fulfill()
        }

        wait(for: [testExpectation], timeout: 10)
    }
}
