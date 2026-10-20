//
//  SecurityUtil.swift
//
//  Created on 02.02.2022.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CryptoKit
import Foundation
import KeychainAccess

/// `SecurityUtilProtocol` provides an interface for security-related utilities.
protocol SecurityUtilProtocol: Sendable {
    /// Save the hashed version of the password to the keychain.
    func save(password: String) async
    
    /// Validates if the given password matches the saved password hash in the keychain.
    func isValid(password: String) -> Bool
    
    /// Check if a password has already been saved in the keychain.
    func hasPassword() -> Bool
}

/// `SecurityUtil` provides utilities for handling password-based functionalities, such as saving, validation, and checking existence in the keychain.
public final class SecurityUtil: SecurityUtilProtocol, @unchecked Sendable {
    /// id to construct keychain
    private let keychainId: String
    
    /// soul to hide user password
    private let soul: String
    
    /// key to store user password
    private let appKey: String
    
    //// keychain object
    private let keychain: Keychain
    
    init(keychainId: String = Secrets.keychainId, soul: String = Secrets.soul, appKey: String = Secrets.appKey) {
        self.keychainId = keychainId
        self.soul = soul
        self.appKey = appKey
        
        keychain = Keychain(service: keychainId)
    }
    
    /// Save the hashed version of the password to the keychain.
    ///
    /// - Parameter password: The password to be hashed and saved.
    func save(password: String) async {
        guard let hashString = hashString(for: password) else {
            try? keychain.remove(appKey)
            
            return
        }
        
        keychain[appKey] = hashString
    }
    
    /// Validates if the given password matches the saved password hash in the keychain.
    ///
    /// - Parameter password: The password to validate.
    /// - Returns: A boolean indicating whether the password is valid or not.
    func isValid(password: String) -> Bool {
        guard let token = keychain[appKey], token.isEmpty == false else {
            return false
        }
        
        guard let hashString = hashString(for: password), hashString.isEmpty == false else {
            return false
        }
        
        return token == hashString
    }
    
    /// Check if a password has already been saved in the keychain.
    ///
    /// - Returns: A boolean indicating whether a password exists in the keychain or not.
    func hasPassword() -> Bool {
        guard let token = keychain[appKey] else {
            return false
        }
        
        return token.isEmpty == false
    }
    
    /// Hashes the given password using SHA256.
    ///
    /// - Parameter password: The password to be hashed.
    /// - Returns: The SHA256 hashed string representation of the password.
    private func hashString(for password: String) -> String? {
        guard !password.isEmpty else {
            return nil
        }
        
        let dataToPack = Data((soul + password).utf8)
        let hashed = SHA256.hash(data: dataToPack)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension SecurityUtil {
    static var preview: SecurityUtil {
        SecurityUtil(keychainId: "preview", soul: "preview", appKey: "preview")
    }
}
