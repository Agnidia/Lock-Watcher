//
//  MockLog.swift
//
//  Created on 30.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

/// Mock logger for unit tests.
/// Uses `@unchecked Sendable` because test mocks don't need thread safety guarantees.
final class LogMock: LogProtocol, @unchecked Sendable {
    var debugMessage: String?
    var infoMessage: String?
    var errorMessage: String?

    /// Every message in call order, for assertions that need more than the last one.
    private(set) var messages: [String] = []

    func debug(_ message: String) {
        debugMessage = message
        messages.append(message)
    }

    func info(_ message: String) {
        infoMessage = message
        messages.append(message)
    }

    func error(_ message: String) {
        errorMessage = message
        messages.append(message)
    }
}
