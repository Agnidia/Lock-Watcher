//
//  UserDefault+PropertyWrapper.swift
//
//  Created on 29.08.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Combine
import Foundation

/// A property wrapper that enables seamless storage and retrieval of Codable objects in UserDefaults.
///
/// When wrapped around a property, this property wrapper will automatically store the property's value in UserDefaults
/// whenever it's set, and retrieve it whenever it's accessed. The property will behave like a normal property to external
/// code.
///
/// - Example:
/// ```swift
/// @UserDefault("user", defaultValue: User.default)
/// var user: User
/// ```
/// With this declaration, every time `user` is set, its value will be stored in UserDefaults, and every time it's accessed,
/// its value will be retrieved from UserDefaults.
///
/// The `UserDefault` property wrapper uses the Codable protocol to encode and decode custom objects into and out of UserDefaults.
/// This makes it possible to store custom objects in UserDefaults as long as they conform to the Codable protocol.
///
@propertyWrapper
struct UserDefault<T: Codable> {
    let key: String
    let defaultValue: T
    
    private let userDefaults: UserDefaults
    
    /// Initializes a new UserDefault property wrapper.
    ///
    /// - Parameters:
    ///   - key: The key under which the value is stored in UserDefaults.
    ///   - defaultValue: The default value to use if UserDefaults doesn't have a value for the specified key.
    ///
    init(_ key: String, defaultValue: T, userDefaults: UserDefaults = UserDefaults(suiteName: Secrets.userDefaultsId)!) {
        self.key = key
        self.defaultValue = defaultValue
        
        self.userDefaults = userDefaults
    }
    
    /// The current value of the property.
    ///
    /// When this value is accessed, it's retrieved from UserDefaults, and when it's set, it's stored in UserDefaults.
    var wrappedValue: T {
        get {
            if let data = userDefaults.object(forKey: key) as? Data {
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print(error)
                    return defaultValue
                }
            } else if let object = userDefaults.object(forKey: key) as? T {
                return object
            } else {
                return defaultValue
            }
        }
        set {
            do {
                let encoded = try JSONEncoder().encode(newValue)
                userDefaults.set(encoded, forKey: key)
            } catch {
                print(error)
            }
        }
    }
}
