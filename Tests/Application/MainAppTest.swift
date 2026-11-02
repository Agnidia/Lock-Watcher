//
//  MainAppTest.swift
//
//  Created on 27.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import UserNotifications
import XCTest
@testable import Lock_Watcher

@MainActor
class AppDelegateModelTests: XCTestCase {
    var model: MockAppDelegateModel!
    
    override func setUp() {
        super.setUp()
        model = MockAppDelegateModel()
    }
    
    func testSetupWithNotification_valid() {
        // Given
        let notification = Notification(name: Notification.Name("TestNotification"))
        
        // Execute
        model.setup(with: notification)
        
        XCTAssertTrue(model.invokedSetup)
        XCTAssertTrue(model.invokedSetupParameters?.localNotification == notification)
    }
    
    func testCheckDropboxAuthWithURLs_valid() throws {
        // Given
        let validDropboxURL = try XCTUnwrap(URL(string: "scheme://dropboxKey"))
        
        // Execute & Assert for valid Dropbox URL
        let validDropboxURLs = [validDropboxURL]
        model.stubbedCheckDropboxAuthResult = true
        XCTAssertTrue(model.checkDropboxAuth(urls: validDropboxURLs) == true)
        XCTAssertTrue(validDropboxURLs == model.invokedCheckDropboxAuthParameters?.urls, "Expected to recognise valid Dropbox URL.")
    }
    
    func testCheckDropboxAuthWithURLs_invalid() throws {
        // Given
        let validDropboxURL = try XCTUnwrap(URL(string: "scheme://dropboxKey"))
        let invalidDropboxURL = try XCTUnwrap(URL(string: "scheme://invalidKey"))
        
        // Execute & Assert for valid Dropbox URL
        let validDropboxURLs = [validDropboxURL]
        let invalidDropboxURLs = [invalidDropboxURL]
        model.stubbedCheckDropboxAuthResult = false
        XCTAssertTrue(model.checkDropboxAuth(urls: invalidDropboxURLs) == false)
        XCTAssertTrue(validDropboxURLs != model.invokedCheckDropboxAuthParameters?.urls, "Expected to recognise valid Dropbox URL.")
    }
}
