//
//  APNsEnvironment.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// The APNs host a device token belongs to: development builds receive sandbox tokens, TestFlight and App Store builds production ones.
enum APNsEnvironment: String, Sendable, Codable, CaseIterable {
    case sandbox
    case production
}

// MARK: - Test Info

// @test-file: Tests/Utils/PairingPayloadTest.swift
