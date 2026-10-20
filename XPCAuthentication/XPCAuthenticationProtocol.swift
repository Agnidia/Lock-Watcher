//
//  XPCAuthenticationProtocol.swift
//
//  Created on 28.03.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// A protocol defining the contract for detecting authentication failure messages in system logs.
@objc
public protocol XPCAuthenticationProtocol {
    /// Detect authentication failure messages in the system log from a given date.
    ///
    /// - Parameters:
    ///   - date: The date from which to begin scanning the system logs.
    ///   - replyBlock: A callback that receives a Boolean value indicating whether an authentication failure message was detected in the logs.
    func detectedAuthenticationFailedFromDate(_ date: Date, _ replyBlock: @escaping (Bool) -> Void)
}
