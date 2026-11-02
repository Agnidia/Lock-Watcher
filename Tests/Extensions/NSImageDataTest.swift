//
//  NSImageDataTest.swift
//
//  Created on 28.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

final class NSImageDataTest: XCTestCase {
    /// Test that valid NSImage converts to non-empty JPEG data
    func testValidImageToJpeg() {
        // Assuming you have a valid image named "Sample" in your test bundle.
        guard let image = NSImage(named: "MenuIcon") else {
            XCTFail("Failed to load the sample image.")
            return
        }
        
        let jpegRepresentation = image.jpegData
        XCTAssertFalse(jpegRepresentation.isEmpty, "JPEG data should not be empty for valid image.")
    }
    
    /// Test that an empty or invalid NSImage converts to empty JPEG data
    func testInvalidImageToJpeg() {
        let image = NSImage()
        let jpegRepresentation = image.jpegData
        XCTAssertTrue(jpegRepresentation.isEmpty, "JPEG data should be empty for an invalid image.")
    }

    /// Test that quality parameter produces different data sizes
    func testJpegDataWithQuality() {
        guard let image = NSImage(named: "MenuIcon") else {
            XCTFail("Failed to load the sample image.")
            return
        }

        let lowQuality = image.jpegData(quality: 0.25)
        let highQuality = image.jpegData(quality: 1.0)

        XCTAssertFalse(lowQuality.isEmpty)
        XCTAssertFalse(highQuality.isEmpty)
        XCTAssertLessThanOrEqual(lowQuality.count, highQuality.count,
                                 "Lower quality should produce smaller or equal data.")
    }
}
