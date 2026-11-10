//
//  PushSettingsView.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import SwiftUI

/// The push channel block in the Sync section.
struct PushSettingsView: View {
    @Binding var isEnabled: Bool
    @Bindable var model: PushPairingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Toggle(isOn: $isEnabled) {
                Text("PushToiPhone")
            }
            .help("PushToiPhoneHelp")
            .accessibilityIdentifier(AccessibilityID.Settings.pushToggle)
            .accessibilityLabel(AccessibilityLabel.Settings.pushToiPhone)
            .accessibilityHint(AccessibilityHint.Settings.toggleHint)

            PushPairingStatusView(phase: PushBlockPhase.make(isEnabled: isEnabled, pairing: model.pairing), model: model)

            if isEnabled {
                OwnAPNsKeyView(model: model)
            }
        }
        .task { await model.refresh() }
        .sheet(isPresented: $model.isPairingSheetPresented) {
            PushPairingSheet(model: model)
        }
    }
}

struct PushPairingStatusView: View {
    let phase: PushBlockPhase
    let model: PushPairingViewModel

    var body: some View {
        switch phase {
        case .disabled:
            EmptyView()
        case .unpaired:
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("PushNotPaired")
                    .font(DesignSystem.Typography.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Button("PushPairIPhone", action: model.startPairing)
                    .accessibilityIdentifier(AccessibilityID.Settings.pushPairButton)
            }
        case .paired(_, let pairedAt):
            HStack(spacing: DesignSystem.Spacing.sm) {
                Label(String(format: NSLocalizedString("PushPairedOn %@", comment: ""), pairedAt.formatted(date: .abbreviated, time: .shortened)),
                      systemImage: "iphone")
                    .font(DesignSystem.Typography.footnote)
                Button("PushForgetIPhone", role: .destructive, action: model.forget)
                    .accessibilityIdentifier(AccessibilityID.Settings.pushForgetButton)
            }
        case .needsRepair:
            HStack(spacing: DesignSystem.Spacing.sm) {
                Label("PushNeedsRepair", systemImage: "exclamationmark.triangle.fill")
                    .font(DesignSystem.Typography.footnote)
                    .foregroundStyle(.orange)
                Button("PushRepairIPhone", action: model.startPairing)
                    .accessibilityIdentifier(AccessibilityID.Settings.pushRepairButton)
            }
        }
    }
}

struct PushPairingSheet: View {
    let model: PushPairingViewModel

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("PushPairTitle")
                .font(.headline)
            Text("PushPairInstructions")
                .font(DesignSystem.Typography.footnote)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            scannerArea
                .frame(width: 320, height: 240)
                .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            if case .rejected(let issue) = model.scanPhase {
                Text(LocalizedStringKey(issue.messageKey))
                    .font(DesignSystem.Typography.footnote)
                    .foregroundStyle(.red)
            }
            Button("ButtonCancel", role: .cancel, action: model.cancelPairing)
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 360)
        .accessibilityIdentifier(AccessibilityID.Settings.pushPairingSheet)
        .task {
            await model.runScan()
        }
    }

    @ViewBuilder
    private var scannerArea: some View {
        switch model.scanPhase {
        case .cameraDenied:
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("PushCameraDenied")
                    .multilineTextAlignment(.center)
                Button("PushOpenCameraSettings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding()
        case .cameraUnavailable:
            Text("PushCameraUnavailable")
                .multilineTextAlignment(.center)
                .padding()
        case .idle, .requestingAccess:
            ProgressView()
        case .scanning, .rejected:
            QRScannerPreview(scanner: model.scanner)
                .overlay(alignment: .bottom) {
                    Text("PushScanning")
                        .font(DesignSystem.Typography.footnote)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                        .padding(6)
                }
        }
    }
}

/// Advanced: the owner's own APNs key, for a companion built under the owner's team.
struct OwnAPNsKeyView: View {
    let model: PushPairingViewModel

    @State private var keyID = ""
    @State private var teamID = ""
    @State private var topic = ""
    @State private var pem = ""
    @State private var isInvalid = false

    var body: some View {
        DisclosureGroup("PushOwnKeyTitle") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if model.hasOwnKey {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("PushOwnKeyInUse")
                            .font(DesignSystem.Typography.footnote)
                        Button("PushOwnKeyClear", role: .destructive, action: model.clearOwnKey)
                    }
                } else {
                    TextField("PushOwnKeyID", text: $keyID)
                    TextField("PushOwnTeamID", text: $teamID)
                    TextField("PushOwnTopic", text: $topic)
                    SecureField("PushOwnKeyPEM", text: $pem)
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button("PushOwnKeySave", action: save)
                            .disabled(keyID.isEmpty || teamID.isEmpty || topic.isEmpty || pem.isEmpty)
                        if isInvalid {
                            Text("PushOwnKeyInvalid")
                                .font(DesignSystem.Typography.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
                Text("PushOwnKeyFootnote")
                    .font(DesignSystem.Typography.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func save() {
        isInvalid = !model.saveOwnKey(keyID: keyID, teamID: teamID, topic: topic, pem: pem)
        pem = ""
        if !isInvalid {
            keyID = ""
            teamID = ""
            topic = ""
        }
    }
}

#Preview("Push block") {
    PushSettingsGallery()
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/PushPairingViewModelTests.swift
