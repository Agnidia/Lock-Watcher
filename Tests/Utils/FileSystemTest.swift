//
//  FileSystemTest.swift
//
//  Created on 30.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

final class FileSystemUtilTests: XCTestCase {
    var fileSystemUtil: FileSystemUtilProtocol!
    var mockLogger: LogMock!
    
    override func setUp() {
        super.setUp()
        mockLogger = LogMock()
        fileSystemUtil = FileSystemUtil(dirName: "lock-watcher-unittest",logger: mockLogger)
    }
    
    override func tearDown() {
        mockLogger = nil
        fileSystemUtil = nil
        super.tearDown()
    }
    
    func testStoreImage_success() throws {
        let image = NSImage.testImage(size: NSSize(width: 64, height: 48))
        let key = "uniqueSuccessKey"
        
        let url = fileSystemUtil.store(image: image, forKey: key)
        
        XCTAssertNotNil(url, "The URL should not be nil when storing an image successfully.")
        XCTAssertTrue(try FileManager.default.fileExists(atPath: XCTUnwrap(url).path))
        XCTAssertNil(mockLogger.debugMessage, "No debug log should be generated when storing an image successfully.")
        
        // Clean up (optional)
        try? FileManager.default.removeItem(at: try XCTUnwrap(url))
    }
    
    func testStoreImage_failed() {
        let image = NSImage() // An empty or invalid image for this test
        let key = "uniqueFailedKey"
        
        let url = fileSystemUtil.store(image: image, forKey: key)
        
        XCTAssertNil(url, "The URL should be nil when storing an image fails.")
        XCTAssertNotNil(mockLogger.debugMessage, "A debug log should be generated when storing an image fails.")
    }
    
    /* func testFilePathGeneration() {
        // This would be a private function normally, but for the purpose of this test example
        // you might want to make it internal or use other techniques to test it.
        
        let key = "uniqueKey"
        let url = fileSystemUtil.filePath(forKey: key)
        
        XCTAssertNotNil(url, "The URL should not be nil when generating a file path successfully.")
        XCTAssert(url?.lastPathComponent == "\(key).jpeg", "The last path component should match the key.")
    } */
}

// Your LogMock from the previous example would also be needed here.
