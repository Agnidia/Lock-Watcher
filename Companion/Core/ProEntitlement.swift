//
//  ProEntitlement.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// The three App Store products that unlock Pro; any one of them is enough.
enum ProProduct {
    static let month = "com.igrsoft.LockWatcher.pro.month"
    static let year = "com.igrsoft.LockWatcher.pro.year"
    static let lifetime = "com.igrsoft.LockWatcher.pro.lifetime"

    /// Display order on the Pro tab.
    static let all = [month, year, lifetime]
}

/// Pure price maths for the plan cards; the store's own formatter turns the results into text, so the output follows the user's currency.
enum ProPricing {
    /// Whole percent the yearly price saves against twelve monthly payments; nil when there is no saving or a price is missing.
    static func savingsPercent(monthly: Decimal, yearly: Decimal) -> Int? {
        guard monthly > 0, yearly > 0 else { return nil }
        let twelveMonths = monthly * 12
        guard yearly < twelveMonths else { return nil }
        var ratio = (twelveMonths - yearly) / twelveMonths * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &ratio, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    static func monthlyEquivalent(yearly: Decimal) -> Decimal? {
        yearly > 0 ? yearly / 12 : nil
    }
}

/// What the views need to know about Pro, so tests can use a stub instead of StoreKit.
@MainActor
protocol ProEntitlementProviding: AnyObject {
    var isPro: Bool { get }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
