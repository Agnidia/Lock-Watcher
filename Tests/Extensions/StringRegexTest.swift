//
//  StringRegexTest.swift
//
//  Created on 28.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

final class StringExtensionTests: XCTestCase {
    /// Test if the function returns correct matches.
    func testValidRegexWithoutMatches() {
        let testString = "CLLocationCoordinate2D(latitude: 51.50998, longitude: -0.1337)"
        let regex = "\\((.*?)\\)"
        let matches = testString.matches(for: regex)
        
        XCTAssertEqual(matches?.first, "latitude: 51.50998, longitude: -0.1337", "Should extract the correct user name.")
    }
    
    /// Test if the function returns correct matches.
    func testValidRegexWithMatches() {
        let testString = "Hello, my phone numbers are (555)-555-5555 and (555)-666-7777"
        let regex = "\\((\\d{3})\\)-\\d{3}-\\d{4}"
        let matches = testString.matches(for: regex)
        
        XCTAssertEqual(matches, ["555", "555"], "Should return correct area codes.")
    }

    /// Ensure that the function returns nil for invalid regex.
    func testInvalidRegex() {
        let testString = "Hello, World!"
        let regex = "["
        let matches = testString.matches(for: regex)
        
        XCTAssertNil(matches, "Should return nil for invalid regex.")
    }
    
    /// Test for specific match group extraction.
    func testMatchGroupExtraction() {
        let testString = "Email: example@example.com, User: JohnDoe"
        let regex = "User: (\\w+)"
        let matches = testString.matches(for: regex)
        
        XCTAssertEqual(matches?.first, "JohnDoe", "Should extract the correct user name.")
    }
}
