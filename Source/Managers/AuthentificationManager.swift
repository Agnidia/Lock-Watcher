//
//  AuthentificationManager.swift
//
//  Created on 21.07.2024.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import LocalAuthentication

final class AuthentificationManager: @unchecked Sendable {
    private let securityUtil: SecurityUtilProtocol
    private let logger: LogProtocol
    
    private var isUnlocked = false
    private let autolockInterval: TimeInterval = 900
    
    init(logger: LogProtocol, securityUtil: SecurityUtilProtocol) {
        self.logger = logger
        self.securityUtil = securityUtil
    }
    
    /// Returns false if cancelled by user.
    func authenticate(with settings: AuthSettings) async throws -> Bool {
        if isUnlocked {
            return true
        }
        if let policy = localAuthPolicy(for: settings) {
            do {
                isUnlocked = try await authenticate(with: policy)
            } catch let error as LAError where error.code == .userFallback {
                isUnlocked = try await authenticateWithPassword()
            }
        } else {
            isUnlocked = try await authenticateWithPassword()
        }
        if isUnlocked {
            lockAfter(autolockInterval)
        }
        return isUnlocked
    }
    
    /// Returns false if cancelled by user.
    private func authenticateWithPassword() async throws -> Bool {
        guard securityUtil.hasPassword() else {
            return true
        }
        
        return try await MainActor.run {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("EnterPassword", comment: "")
            alert.addButton(withTitle: NSLocalizedString("ButtonOk", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("ButtonCancel", comment: ""))
            alert.alertStyle = .warning
            let inputTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            alert.accessoryView = inputTextField
            if alert.runModal() == .alertFirstButtonReturn {
                if securityUtil.isValid(password: inputTextField.stringValue) {
                    return true
                } else {
                    throw Failure.passwordAuthentificationFailed
                }
            } else {
                return false
            }
        }
    }
    
    /// Returns false if cancelled by user.
    private func authenticate(with policy: LAPolicy) async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(policy, error: &error) else  {
            if let error {
                logger.error(String(describing: error))
                throw error
            } else {
                logger.error(String(describing: Failure.localAuthentificationFailed.description))
                throw Failure.localAuthentificationFailed
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: authentificationReason) { success, authenticationError in
                if success {
                    continuation.resume(returning: true)
                } else if let error = authenticationError as? LAError, error.code == LAError.userCancel {
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(throwing: authenticationError ?? Failure.localAuthentificationFailed)
                }
            }
        }
    }
    
    private func lockAfter(_ interval: TimeInterval) {
        Timer.scheduledTimer(withTimeInterval: autolockInterval, repeats: false, block: resetUnlock)
    }
    
    @Sendable
    private func resetUnlock(_ timer: Timer) {
        isUnlocked = false
    }
    
    private var authentificationReason: String {
        NSLocalizedString("AuthInfo", comment: "")
    }
    
    private func localAuthPolicy(for settings: AuthSettings) -> LAPolicy? {
        if settings.devicePassword {
            .deviceOwnerAuthentication
        } else {
            if settings.biometrics, settings.watch {
                .deviceOwnerAuthenticationWithBiometricsOrWatch
            } else if settings.biometrics {
                .deviceOwnerAuthenticationWithBiometrics
            } else if settings.watch {
                .deviceOwnerAuthenticationWithWatch
            } else {
                nil
            }
        }
    }
    }

extension AuthentificationManager {
    enum Failure: Error, CustomStringConvertible {
        case localAuthentificationFailed
        case passwordAuthentificationFailed
        
        var description: String {
            switch self {
            case .localAuthentificationFailed:
                NSLocalizedString("Auth_deviceAuthentificationFailed", comment: "")
            case .passwordAuthentificationFailed:
                NSLocalizedString("Auth_passwordAuthentificationFailed", comment: "")
            }
        }
            }
    }
