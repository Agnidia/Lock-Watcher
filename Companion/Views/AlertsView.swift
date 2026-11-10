//
//  AlertsView.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

struct AlertsView: View {
    let inbox: AlertInbox

    var body: some View {
        if inbox.alerts.isEmpty {
            ContentUnavailableView("AlertsEmptyTitle", systemImage: "bell.slash", description: Text("AlertsEmptyMessage"))
        } else {
            List(inbox.alerts) { alert in
                AlertRow(alert: alert)
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
                Label(String(format: "%.4f, %.4f", latitude, longitude), systemImage: "location")
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
