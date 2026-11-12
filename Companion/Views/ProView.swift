//
//  ProView.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import StoreKit
import SwiftUI

/// The blue of the app icon's gradient start (display P3), shared by the Pro tab and its icon.
enum ProTint {
    private static let components = (red: 0.23926, green: 0.54102, blue: 0.77637)
    
    static let color = Color(.displayP3, red: components.red, green: components.green, blue: components.blue)
    static let uiColor = UIColor(displayP3Red: components.red, green: components.green, blue: components.blue, alpha: 1)
}

struct ProView: View {
    private static let termsURL = URL(string: "https://agnidia.com/info/app/lockwatcher/terms.html")
    private static let privacyURL = URL(string: "https://agnidia.com/info/app/lockwatcher/policy.html")
    
    let store: ProStore
    
    @State private var isManagingSubscription = false
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    /// A sticky bar would cover a third of the screen at accessibility sizes, so the button then scrolls with the content.
    private var usesStickyBar: Bool {
        !dynamicTypeSize.isAccessibilitySize
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if store.isPro {
                    ProActiveView(store: store) { isManagingSubscription = true }
                } else {
                    ProHero(isActive: false)
                    ProComparisonCard()
                    ProPlanPicker(store: store)
                    if !usesStickyBar, store.selectedPlan != nil {
                        ProPurchaseBar(store: store)
                    }
                }
                ProFooter(termsURL: Self.termsURL, privacyURL: Self.privacyURL, isFree: !store.isPro) {
                    Task { await store.restore() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            if usesStickyBar, !store.isPro, store.selectedPlan != nil {
                ProPurchaseBar(store: store)
            }
        }
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
        .sensoryFeedback(.selection, trigger: store.selectedPlanID)
        .sensoryFeedback(.success, trigger: store.isPro) { wasPro, isPro in !wasPro && isPro }
        .task { await store.refresh() }
    }
}

// MARK: - Hero

private struct ProHero: View {
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(isActive ? "ProActiveTitle" : "ProTitle")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(isActive ? "ProActiveMessage" : "ProPromise")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Free versus Pro

private struct ProComparisonCard: View {
    private enum Cell {
        case included
        case notIncluded
        case value(Int)
    }
    
    private struct Row: Identifiable {
        let id: String
        let symbol: String
        let title: LocalizedStringKey
        let free: Cell
        let pro: Cell
    }
    
    private static let rows = [
        Row(id: "alerts", symbol: "bell.fill", title: "ProRowAlerts", free: .included, pro: .included),
        Row(id: "photos", symbol: "photo.on.rectangle", title: "ProRowPhotos", free: .included, pro: .included),
        Row(id: "details", symbol: "map.fill", title: "ProRowDetails", free: .notIncluded, pro: .included),
        Row(id: "photoTools", symbol: "arrow.up.left.and.arrow.down.right.rectangle", title: "ProRowPhotoTools", free: .notIncluded, pro: .included),
        Row(id: "history", symbol: "clock.arrow.circlepath", title: "ProRowHistory",
            free: .value(AlertInbox.freeVisibleLimit), pro: .value(AlertInbox.capacity))
    ]
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stacked
            } else {
                table
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        .accessibilityElement(children: .contain)
    }
    
    private var table: some View {
        Grid(alignment: .center, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Color.clear.frame(height: 1)
                Text("ProCompareFree")
                    .font(.footnote.bold())
                    .foregroundStyle(.secondary)
                Text("ProComparePro")
                    .font(.footnote.bold())
            }
            Divider()
            ForEach(Self.rows) { row in
                GridRow {
                    HStack(alignment: .top, spacing: 10) {
                        featureIcon(row.symbol)
                        Text(row.title)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    cell(row.free, isPro: false)
                    cell(row.pro, isPro: true)
                }
            }
        }
    }
    
    /// One block per feature, because three columns do not fit at accessibility text sizes.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Self.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        featureIcon(row.symbol)
                        Text(row.title)
                            .font(.headline)
                    }
                    HStack {
                        Text("ProCompareFree")
                            .foregroundStyle(.secondary)
                        Spacer()
                        cell(row.free, isPro: false)
                    }
                    HStack {
                        Text("ProComparePro")
                        Spacer()
                        cell(row.pro, isPro: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
    
    /// A fixed-width frame keeps the titles aligned although the symbols differ in width.
    private func featureIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.subheadline)
            .foregroundStyle(ProTint.color)
            .frame(width: 16)
            .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private func cell(_ cell: Cell, isPro: Bool) -> some View {
        switch cell {
        case .included:
            Image(systemName: "checkmark")
                .font(.subheadline.bold())
                .foregroundStyle(isPro ? ProTint.color : Color.secondary)
                .accessibilityLabel(Text("ProIncluded"))
        case .notIncluded:
            Image(systemName: "minus")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("ProNotIncluded"))
        case .value(let number):
            Text(number, format: .number)
                .font(.subheadline.weight(isPro ? .bold : .regular))
                .foregroundStyle(isPro ? Color.primary : Color.secondary)
        }
    }
}

// MARK: - Plans

private struct ProPlanPicker: View {
    private static let placeholders = [
        ProPlan(id: "placeholder.1", kind: .year, title: "Pro Yearly", price: "$0.00", monthlyEquivalent: "$0.00", savingsPercent: nil),
        ProPlan(id: "placeholder.2", kind: .month, title: "Pro Monthly", price: "$0.00", monthlyEquivalent: nil, savingsPercent: nil),
        ProPlan(id: "placeholder.3", kind: .lifetime, title: "Pro Lifetime", price: "$0.00", monthlyEquivalent: nil, savingsPercent: nil)
    ]
    
    let store: ProStore
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 12) {
            if !store.plans.isEmpty {
                ForEach(store.plans) { plan in
                    PlanCard(plan: plan, isSelected: plan.id == store.selectedPlan?.id) {
                        store.selectedPlanID = plan.id
                    }
                }
            } else if store.isLoadingProducts {
                ForEach(Self.placeholders) { plan in
                    PlanCard(plan: plan, isSelected: false) {}
                        .redacted(reason: .placeholder)
                        .disabled(true)
                        .accessibilityHidden(true)
                }
            } else {
                unavailable
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: store.selectedPlanID)
    }
    
    private var unavailable: some View {
        VStack(spacing: 12) {
            Text("ProUnavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("ProRetry") {
                Task { await store.retryLoadingProducts() }
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct PlanCard: View {
    let plan: ProPlan
    let isSelected: Bool
    let select: () -> Void
    
    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                        if let savings = plan.savingsPercent {
                            Text("ProSave \(savings)")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(ProTint.color.opacity(0.25)))
                        }
                    }
                    detail
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(plan.price)
                    .font(.headline)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isSelected ? ProTint.color : Color.clear, lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    @ViewBuilder
    private var detail: some View {
        switch plan.kind {
        case .year:
            if let monthly = plan.monthlyEquivalent {
                Text("ProDetailYear \(monthly)")
            } else {
                Text("ProDetailYearPlain")
            }
        case .month:
            Text("ProDetailMonth")
        case .lifetime:
            Text("ProDetailLifetime")
        }
    }
}

// MARK: - Purchase bar

private struct ProPurchaseBar: View {
    let store: ProStore
    
    var body: some View {
        VStack(spacing: 4) {
            if store.purchaseFailed {
                Label("ProPurchaseFailed", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Color(.systemRed))
            }
            Button {
                Task { await store.purchaseSelectedPlan() }
            } label: {
                ZStack {
                    if store.isPurchasing {
                        ProgressView()
                            .tint(.black)
                    } else {
                        title
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(ProTint.color)
            .controlSize(.large)
            .disabled(store.isPurchasing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
    
    @ViewBuilder
    private var title: some View {
        if let plan = store.selectedPlan {
            switch plan.kind {
            case .year: Text("ProCtaYear \(plan.price)")
            case .month: Text("ProCtaMonth \(plan.price)")
            case .lifetime: Text("ProCtaLifetime \(plan.price)")
            }
        }
    }
}

// MARK: - Active

private struct ProActiveView: View {
    let store: ProStore
    let manage: () -> Void
    
    private var isLifetime: Bool {
        store.activeProductId == ProProduct.lifetime
    }
    
    var body: some View {
        VStack(spacing: 24) {
            ProHero(isActive: true)
            ProComparisonCard()
            VStack(spacing: 12) {
                HStack {
                    Text("ProPlanLabel")
                    Spacer()
                    planName
                        .bold()
                }
                Divider()
                HStack {
                    Text("ProStatusLabel")
                    Spacer()
                    Text(isLifetime ? "ProStatusLifetime" : "ProStatusSubscribed")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            .accessibilityElement(children: .combine)
            if !isLifetime {
                Button("ProManage", action: manage)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Button("ProRestore") {
                Task { await store.restore() }
            }
            .font(.subheadline)
            .frame(minHeight: 44)
        }
    }
    
    @ViewBuilder
    private var planName: some View {
        switch store.activeProductId {
        case ProProduct.lifetime: Text("ProPlanLifetime")
        case ProProduct.year: Text("ProPlanYear")
        default: Text("ProPlanMonth")
        }
    }
}

// MARK: - Footer

private struct ProFooter: View {
    let termsURL: URL?
    let privacyURL: URL?
    /// Free accounts get the renewal note and the restore link; Pro accounts have Restore in their own card.
    let isFree: Bool
    let restore: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            if isFree {
                Text("ProSubscriptionNote")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) { links }
                VStack(spacing: 0) { links }
            }
            .font(.footnote)
        }
    }
    
    @ViewBuilder
    private var links: some View {
        if isFree {
            Button("ProRestore", action: restore)
                .frame(minHeight: 44)
        }
        if let termsURL {
            Link("ProTerms", destination: termsURL)
                .frame(minHeight: 44)
        }
        if let privacyURL {
            Link("ProPrivacy", destination: privacyURL)
                .frame(minHeight: 44)
        }
    }
}

#if DEBUG
#Preview("Free, offers") {
    ProView(store: PreviewModels.pro(active: false))
}

#Preview("Pro active") {
    ProView(store: PreviewModels.pro(active: true))
}
#endif

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
