//
//  DateFormatterTest.swift
//
//  Created on 28.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

final class DateExtensionTests: XCTestCase {
    func testDefaultFormatStyles() {
        // Assert the styles of the defaultFormat
        XCTAssertEqual(Date.defaultFormat.dateStyle, .short)
        XCTAssertEqual(Date.defaultFormat.timeStyle, .short)
        XCTAssertEqual(Date.defaultFormat.locale, .init(identifier: "en"))
        XCTAssertEqual(Date.defaultFormat.timeZone, .gmt)
    }

    func testDefaultFormatFormatting() {
        // Create a known date for testing. E.g., January 1, 2000, 12:34 PM
        // Note: This date setup assumes GMT. Adjust if you want a different time zone.
        var components = DateComponents()
        components.year = 2008
        components.month = 1
        components.day = 1
        components.hour = 12
        components.minute = 34
        components.timeZone = .gmt
        
        guard let knownDate = Calendar.current.date(from: components) else {
            XCTFail("Failed to create a known date")
            return
        }

        // Format the known date using the extension
        let formattedDate = Date.defaultFormat.string(from: knownDate)

        // Check the formatted string
        // This expected value assumes the US locale. Adjust based on the default locale or explicitly set the locale of the defaultFormat.
        XCTAssertEqual(formattedDate, "1/1/08, 12:34 PM")
    }
}
