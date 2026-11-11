//
//  ProStore.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import SKHelperCore
import StoreKit

/// What a plan card shows; plain text so previews and DEBUG fixtures need no StoreKit product.
struct ProPlan: Identifiable, Equatable {
    enum Kind { case year, month, lifetime }

    let id: String
    let kind: Kind
    let title: String
    let price: String
    /// Yearly only: the same price spread over twelve months, already formatted.
    let monthlyEquivalent: String?
    /// Yearly only: whole percent saved against twelve monthly payments.
    let savingsPercent: Int?
}

/// Pro status on top of SKHelper.
///
/// `SKHelperProduct.hasEntitlement` is a plain property that SwiftUI cannot observe, so `isPro` is recomputed after every event that can change it.
@MainActor
@Observable
final class ProStore: ProEntitlementProviding {
    private(set) var isPro: Bool
    /// The Pro product the user owns, preferring the longest one; nil when free.
    private(set) var activeProductId: String?
    /// In `ProProduct.all` order; empty until the App Store answers.
    private(set) var products: [SKHelperProduct] = []
    private(set) var plans: [ProPlan] = []
    var selectedPlanID = ProProduct.year
    private(set) var isLoadingProducts: Bool
    private(set) var isPurchasing = false
    /// True after a purchase that failed; a cancelled or pending purchase is not a failure.
    private(set) var purchaseFailed = false

    @ObservationIgnored private let helper: SKHelper?

    /// `fixtureIsPro` skips StoreKit completely for DEBUG screenshot states; `fixturePlans` fills the plan cards without the App Store.
    init(fixtureIsPro: Bool? = nil, fixturePlans: [ProPlan] = []) {
        guard let fixtureIsPro else {
            isPro = false
            isLoadingProducts = true
            helper = SKHelper()
            listenForChanges()
            return
        }
        isPro = fixtureIsPro
        activeProductId = fixtureIsPro ? ProProduct.year : nil
        plans = fixturePlans
        isLoadingProducts = false
        helper = nil
    }

    var selectedPlan: ProPlan? {
        plans.first { $0.id == selectedPlanID } ?? plans.first
    }

    func purchaseSelectedPlan() async {
        guard let helper, !isPurchasing,
              let item = products.first(where: { $0.id == selectedPlan?.id })
        else { return }
        isPurchasing = true
        purchaseFailed = false
        let state = await helper.purchase(item.product).purchaseState
        isPurchasing = false
        switch state {
        case .failed, .failedVerification, .error, .userCannotMakePayments:
            purchaseFailed = true
        default:
            break
        }
        await refresh()
    }

    /// A signed-in Apple ID that bought Pro on another device gets it back.
    func restore() async {
        guard helper != nil else { return }
        try? await AppStore.sync()
        await refresh()
    }

    /// Asks the App Store for the prices again after a failed load.
    func retryLoadingProducts() async {
        guard let helper else { return }
        isLoadingProducts = true
        _ = await helper.requestProducts(force: true)
        await refresh()
        isLoadingProducts = false
    }

    /// Re-reads the owned products; every activation calls this because a subscription can lapse while the app is closed.
    func refresh() async {
        guard let helper else { return }
        products = ProProduct.all.compactMap { id in helper.products.first { $0.id == id } }
        plans = Self.makePlans(from: products)
        if !products.isEmpty {
            isLoadingProducts = false
        }
        var owned: [String] = []
        for id in ProProduct.all where await helper.isPurchased(productId: id) {
            owned.append(id)
        }
        activeProductId = [ProProduct.lifetime, ProProduct.year, ProProduct.month].first(where: owned.contains)
        isPro = activeProductId != nil
    }

    /// Yearly first because it is the preselected, best-value plan.
    private static func makePlans(from products: [SKHelperProduct]) -> [ProPlan] {
        let monthly = products.first { $0.id == ProProduct.month }?.product
        let ordered = [ProProduct.year, ProProduct.month, ProProduct.lifetime]
        return ordered.compactMap { id in
            guard let product = products.first(where: { $0.id == id })?.product else { return nil }
            switch id {
            case ProProduct.year:
                let equivalent = ProPricing.monthlyEquivalent(yearly: product.price).map { product.priceFormatStyle.format($0) }
                let savings = monthly.flatMap { ProPricing.savingsPercent(monthly: $0.price, yearly: product.price) }
                return ProPlan(id: id, kind: .year, title: product.displayName, price: product.displayPrice,
                               monthlyEquivalent: equivalent, savingsPercent: savings)
            case ProProduct.month:
                return ProPlan(id: id, kind: .month, title: product.displayName, price: product.displayPrice,
                               monthlyEquivalent: nil, savingsPercent: nil)
            default:
                return ProPlan(id: id, kind: .lifetime, title: product.displayName, price: product.displayPrice,
                               monthlyEquivalent: nil, savingsPercent: nil)
            }
        }
    }

    private func listenForChanges() {
        guard let helper else { return }
        helper.productsAvailable.append { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        helper.transactionUpdateListener = { [weak self] _, _, _ in
            Task { @MainActor in await self?.refresh() }
        }
        helper.subscriptionStatusChange = { [weak self] _, _, _, _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
        // Without an answer in this time the prices count as unavailable and the view offers a retry instead of a placeholder.
        Task {
            try? await Task.sleep(for: .seconds(6))
            isLoadingProducts = false
        }
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
