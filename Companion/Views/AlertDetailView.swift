//
//  AlertDetailView.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import MapKit
import SwiftUI
import UIKit

/// Everything one alert carries, for Pro. A card appears only when its data arrived, because the Mac omits location, IP and trace when the owner turned them off.
struct AlertDetailView: View {
    let alert: ReceivedAlert
    let library: CloudPhotoLibrary

    @State private var copiedCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AlertHeader(alert: alert)
                AlertWhenCard(alert: alert)
                AlertWhereCard(alert: alert, copy: copy)
                if alert.ip != nil || alert.traceRoute != nil {
                    AlertNetworkCard(alert: alert, copy: copy)
                }
                if alert.mediaKind != nil {
                    AlertCaptureCard(alert: alert, library: library)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AlertDetailTitle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: AlertFormat.shareText(for: alert)) {
                    Label("AlertShare", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sensoryFeedback(.success, trigger: copiedCount)
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        copiedCount += 1
    }
}

// MARK: - Cards

private struct DetailCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CopyButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    @State private var showsCopied = false

    var body: some View {
        Button {
            action()
            showsCopied = true
        } label: {
            Label(showsCopied ? "AlertCopied" : title, systemImage: showsCopied ? "checkmark" : "doc.on.doc")
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .task(id: showsCopied) {
            guard showsCopied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            showsCopied = false
        }
    }
}

private struct AlertHeader: View {
    let alert: ReceivedAlert

    @ScaledMetric(relativeTo: .title) private var badge = 56.0

    private var trigger: AlertTrigger? {
        AlertTrigger(alert: alert)
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: trigger?.symbol ?? AlertTrigger.fallbackSymbol)
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: badge, height: badge)
                .background(.tint.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            if let trigger {
                Text(LocalizedStringKey(trigger.titleKey))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
            } else {
                Text(alert.body)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            if let host = alert.host {
                Label(host, systemImage: "laptopcomputer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct AlertWhenCard: View {
    let alert: ReceivedAlert

    var body: some View {
        DetailCard(title: "AlertWhen") {
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.headline)
                Text(alert.date, format: .dateTime.hour().minute().second())
                    .font(.title3.monospacedDigit())
                Text(alert.date.formatted(.relative(presentation: .named)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let macTime = AlertFormat.macLocalTime(of: alert) {
                    Label {
                        Text("AlertMacTime \(macTime)")
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct AlertWhereCard: View {
    let alert: ReceivedAlert
    let copy: (String) -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        DetailCard(title: "AlertWhere") {
            if let latitude = alert.latitude, let longitude = alert.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                let text = AlertFormat.coordinates(latitude: latitude, longitude: longitude)
                Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200)), interactionModes: []) {
                    Marker("", coordinate: coordinate)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
                Text(text)
                    .font(.body.monospacedDigit())
                    .textSelection(.enabled)
                ViewThatFits(in: .horizontal) {
                    HStack { actions(latitude: latitude, longitude: longitude, text: text) }
                    VStack(alignment: .leading) { actions(latitude: latitude, longitude: longitude, text: text) }
                }
            } else {
                Text("AlertNoLocation")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func actions(latitude: Double, longitude: Double, text: String) -> some View {
        if let url = AlertFormat.mapsURL(latitude: latitude, longitude: longitude) {
            Button {
                openURL(url)
            } label: {
                Label("AlertOpenInMaps", systemImage: "map")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        CopyButton(title: "AlertCopyCoordinates") { copy(text) }
    }
}

private struct AlertNetworkCard: View {
    let alert: ReceivedAlert
    let copy: (String) -> Void

    @State private var showsFullTrace = false

    private static let collapsedLines = 5

    var body: some View {
        DetailCard(title: "AlertNetwork") {
            if let ip = alert.ip {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AlertIPAddress")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(ip)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                    Spacer(minLength: 8)
                    CopyButton(title: "AlertCopy") { copy(ip) }
                }
            }
            if let trace = alert.traceRoute {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AlertTraceRoute")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(trace)
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(showsFullTrace ? nil : Self.collapsedLines)
                        .textSelection(.enabled)
                    HStack {
                        Button(showsFullTrace ? "AlertShowLess" : "AlertShowAll") {
                            withAnimation(.snappy) { showsFullTrace.toggle() }
                        }
                        .frame(minHeight: 44)
                        Spacer()
                        CopyButton(title: "AlertCopy") { copy(trace) }
                    }
                }
            }
        }
    }
}

private struct AlertCaptureCard: View {
    let alert: ReceivedAlert
    let library: CloudPhotoLibrary

    private var photo: CloudPhoto? {
        guard case .loaded(let photos) = library.phase else { return nil }
        return photos.first { $0.id == alert.fileName }
    }

    var body: some View {
        DetailCard(title: "AlertCapture") {
            if alert.mediaKind == PushAlertPayload.videoMedia {
                Label("AlertVideoRecorded", systemImage: "video")
                    .foregroundStyle(.secondary)
            } else if let photo {
                NavigationLink(value: photo) {
                    CapturePhoto(photo: photo, library: library)
                }
                .buttonStyle(.plain)
            } else {
                missing
            }
        }
        // The alert can arrive before iCloud lists the file, so opening the card looks again.
        .task {
            if alert.mediaKind == PushAlertPayload.photoMedia, photo == nil {
                await library.refresh()
            }
        }
    }

    @ViewBuilder
    private var missing: some View {
        switch library.phase {
        case .loading:
            ProgressView("PhotosLoading")
        case .unavailable:
            Label("PhotosUnavailableTitle", systemImage: "icloud.slash")
                .foregroundStyle(.secondary)
        case .failed, .empty, .loaded:
            VStack(alignment: .leading, spacing: 8) {
                Label("AlertPhotoNotYet", systemImage: "icloud.and.arrow.down")
                    .foregroundStyle(.secondary)
                Button("PhotosRetry") {
                    Task { await library.refresh() }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
            }
        }
    }
}

private struct CapturePhoto: View {
    let photo: CloudPhoto
    let library: CloudPhotoLibrary

    @State private var state: CloudPhotoImageState = .loading

    var body: some View {
        Color.secondary.opacity(0.15)
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay { image }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("PhotoAccessibilityLabel")
            .accessibilityAddTraits(.isButton)
            .task(id: photo.id) {
                let result = await library.image(for: photo, maxPixelSize: 1200)
                if !Task.isCancelled {
                    state = result
                }
            }
    }

    @ViewBuilder
    private var image: some View {
        switch state {
        case .loading:
            ProgressView()
        case .loaded(let cgImage):
            Image(decorative: cgImage, scale: 1)
                .resizable()
                .scaledToFill()
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
