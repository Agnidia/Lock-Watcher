//
//  LoggerProtocol.swift
//
//  Created on 29.08.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// `LogProtocol` provides structure for logging.
///
/// Conforming types must be `Sendable` to allow safe use across actor boundaries.
protocol LogProtocol: Sendable {
    /// Logs a debug message.
    /// - Parameter message: The message to be logged.
    func debug(_ message: String)
    
    /// Logs an informational message.
    /// - Parameter message: The message to be logged.
    func info(_ message: String)
    
    /// Logs an error message.
    /// - Parameter message: The message to be logged.
    func error(_ message: String)
}
