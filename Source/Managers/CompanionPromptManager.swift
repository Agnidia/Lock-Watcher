//
//  CompanionPromptManager.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit

/// Shows the invitation to install and pair the iPhone companion.
@MainActor
protocol CompanionPromptPresenting {
    func presentCompanionPrompt()
}

/// Invites the owner, once, to get the iPhone companion, a minute after launch and only while no iPhone is paired.
@MainActor
final class CompanionPromptManager {
    /// How long after launch the invitation waits, so it never competes with first-launch setup.
    nonisolated static let delay: Duration = .seconds(60)

    private var settings: AppSettingsProtocol

    private let store: any APNsCredentialStoring

    private let presenter: any CompanionPromptPresenting

    private let now: () -> Date

    private let delay: Duration

    private var task: Task<Void, Never>?

    init(settings: AppSettingsProtocol,
         store: any APNsCredentialStoring,
         presenter: any CompanionPromptPresenting,
         delay: Duration = CompanionPromptManager.delay,
         now: @escaping () -> Date = Date.init)
    {
        self.settings = settings
        self.store = store
        self.presenter = presenter
        self.delay = delay
        self.now = now
    }

    /// Starts the wait. A second call, or a launch where the prompt is already done, starts nothing.
    func applicationDidLaunch() {
        guard task == nil, settings.ui.companionPromptShownAt == nil else { return }
        task = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.evaluate()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Returns true when the invitation was shown.
    @discardableResult
    func evaluate() async -> Bool {
        guard settings.ui.companionPromptShownAt == nil, await Self.pairingStatus(of: store) == .unpaired else { return false }
        // Marked before presenting, so a crash or force quit during the alert cannot show it again.
        settings.ui.companionPromptShownAt = now()
        presenter.presentCompanionPrompt()
        return true
    }

    /// Reads the Keychain off the main actor, because Security blocks the calling thread on every item lookup.
    @concurrent
    private nonisolated static func pairingStatus(of store: any APNsCredentialStoring) async -> PairingStatus {
        store.pairingStatus()
    }
}

/// A non-modal alert that never blocks the menu bar app; its buttons close it themselves.
@MainActor
final class CompanionPromptPresenter: NSObject, CompanionPromptPresenting {
    private let storeURL: URL

    /// Keeps the alert alive until the user answers.
    private var visibleAlert: NSAlert?

    init(storeURL: URL = CompanionDownloadView.storeURL) {
        self.storeURL = storeURL
    }

    func presentCompanionPrompt() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("CompanionPromptTitle", comment: "")
        alert.informativeText = NSLocalizedString("CompanionPromptBody", comment: "")
        let downloadButton = alert.addButton(withTitle: NSLocalizedString("CompanionDownload", comment: ""))
        downloadButton.target = self
        downloadButton.action = #selector(download)
        let laterButton = alert.addButton(withTitle: NSLocalizedString("CompanionPromptLater", comment: ""))
        laterButton.target = self
        laterButton.action = #selector(dismissAlert)
        alert.window.level = .floating
        visibleAlert = alert
        // NSAlert lays out lazily inside runModal; a window shown directly needs it done first.
        alert.layout()
        alert.window.center()
        alert.window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func download() {
        NSWorkspace.shared.open(storeURL)
        dismissAlert()
    }

    @objc
    private func dismissAlert() {
        visibleAlert?.window.orderOut(nil)
        visibleAlert = nil
    }
}

// MARK: - Test Info

// @test-file: Tests/Managers/CompanionPromptManagerTest.swift
