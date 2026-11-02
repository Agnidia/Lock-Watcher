//
//  UserDefaultPropertyWrapperTest.swift
//
//  Created on 28.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

/// Define a mock UserDefaults to avoid changing the actual UserDefaults
final class MockUserDefaults: UserDefaults {
    var storage: [String: Any] = [:]
    
    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    override func object(forKey defaultName: String) -> Any? {
        storage[defaultName]
    }
}

/// Mock the Secrets struct
enum Secrets {
    static let userDefaultsId = "com.test.UserDefaultsId"
}

final class UserDefaultTests: XCTestCase {
    /// 1. Test if the default value is returned when UserDefaults doesn't have the specified key.
    func testDefaultValue() throws {
        let userDefaults = try XCTUnwrap(MockUserDefaults(suiteName: Secrets.userDefaultsId))
        let wrapper = UserDefault<Int>("testKey", defaultValue: 5, userDefaults: userDefaults)
        
        XCTAssertEqual(wrapper.wrappedValue, 5)
    }

    /// 2. Test if the setter correctly encodes and saves a value.
    func testSetter() throws {
        let userDefaults = try XCTUnwrap(MockUserDefaults(suiteName: Secrets.userDefaultsId))
        var wrapper = UserDefault<Int>("testKey", defaultValue: 5, userDefaults: userDefaults)
        
        wrapper.wrappedValue = 10
        let data = try XCTUnwrap(userDefaults.storage["testKey"] as? Data)
        let decodedValue = try? JSONDecoder().decode(Int.self, from: data)
        
        XCTAssertEqual(decodedValue, 10)
    }

    /// 3. Test if the getter correctly retrieves and decodes a value.
    func testGetter() throws {
        let userDefaults = try XCTUnwrap(MockUserDefaults(suiteName: Secrets.userDefaultsId))
        let wrapper = UserDefault<Int>("testKey", defaultValue: 5, userDefaults: userDefaults)
        
        let data = try JSONEncoder().encode(20)
        userDefaults.set(data, forKey: "testKey")
        
        XCTAssertEqual(wrapper.wrappedValue, 20)
    }
    
    /// 4. Test for non-encodable/decodable values.
    func testNonEncodableValue() throws {
        let userDefaults = try XCTUnwrap(MockUserDefaults(suiteName: Secrets.userDefaultsId))
        let wrapper = UserDefault<String>("testKey", defaultValue: "default", userDefaults: userDefaults)
        
        userDefaults.set(10, forKey: "testKey")
        
        XCTAssertEqual(wrapper.wrappedValue, "default")
    }
}
