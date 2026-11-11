//
//  AlertsView.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

struct AlertsView: View {
    let inbox: AlertInbox
    let photos: CloudPhotoLibrary
    let isPro: Bool
    let showPro: () -> Void
    /// Holds alerts and photos, so it is untyped.
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("TabAlerts")
                .navigationDestination(for: ReceivedAlert.self) { alert in
                    AlertDetailView(alert: alert, library: photos)
                }
                .navigationDestination(for: CloudPhoto.self) { photo in
                    PhotoDetailView(photo: photo, library: photos, isPro: isPro, showPro: showPro)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if inbox.alerts.isEmpty {
            ContentUnavailableView("AlertsEmptyTitle", systemImage: "bell.slash", description: Text("AlertsEmptyMessage"))
        } else {
            List {
                ForEach(inbox.visibleAlerts(isPro: isPro)) { alert in
                    if isPro {
                        NavigationLink(value: alert) {
                            AlertRow(alert: alert)
                        }
                    } else {
                        // Free accounts see the row, but the detail is a Pro benefit, so a tap leads to the offer.
                        Button(action: showPro) {
                            HStack {
                                AlertRow(alert: alert)
                                Spacer(minLength: 8)
                                Image(systemName: "lock")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("AlertDetailProHint")
                    }
                }
                let hidden = inbox.hiddenCount(isPro: isPro)
                if hidden > 0 {
                    Section {
                        Button(action: showPro) {
                            Label("AlertsUpgrade \(hidden)", systemImage: "lock")
                        }
                    }
                }
            }
        }
    }
}

struct AlertRow: View {
    let alert: ReceivedAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(alert.body)
                .font(.headline)
            Text(alert.date, format: .dateTime.day().month().year().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let latitude = alert.latitude, let longitude = alert.longitude {
                Label(AlertFormat.coordinates(latitude: latitude, longitude: longitude), systemImage: "location")
                    .font(.caption)
            }
            if let ip = alert.ip {
                Label(ip, systemImage: "network")
                    .font(.caption)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
