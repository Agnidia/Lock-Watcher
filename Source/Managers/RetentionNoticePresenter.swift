//
//  RetentionNoticePresenter.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import UserNotifications

/// Tells the user, once, when files captured before the upgrade start to be deleted.
@MainActor
protocol RetentionNoticePresenting {
    func presentUpgradeNotice(period: RetentionPeriod, firstDeletion: Date) async
}

/// Posts a local notification when allowed, otherwise shows a non-modal alert window that never blocks launch.
@MainActor
final class RetentionNoticePresenter: NSObject, RetentionNoticePresenting {
    private let logger: LogProtocol

    /// Keeps the non-modal alert alive until the user dismisses it.
    private var visibleAlert: NSAlert?

    init(logger: LogProtocol = Log(category: .retention)) {
        self.logger = logger
    }

    func presentUpgradeNotice(period: RetentionPeriod, firstDeletion: Date) async {
        let title = NSLocalizedString("RetentionNoticeTitle", comment: "")
        let body = String(format: NSLocalizedString("RetentionNoticeBody %@ %@", comment: ""),
                          period.title,
                          DateFormatter.localizedString(from: firstDeletion, dateStyle: .medium, timeStyle: .none))

        if await postNotification(title: title, body: body) {
            return
        }

        showAlert(title: title, body: body)
    }

    private func showAlert(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        let button = alert.addButton(withTitle: NSLocalizedString("ButtonOk", comment: ""))
        // Not run modally: the button closes the window itself, so launch and other windows stay usable.
        button.target = self
        button.action = #selector(dismissAlert)
        alert.window.level = .floating
        visibleAlert = alert
        // NSAlert lays out lazily inside runModal; a window shown directly needs it done first.
        alert.layout()
        alert.window.center()
        alert.window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func dismissAlert() {
        visibleAlert?.window.orderOut(nil)
        visibleAlert = nil
    }

    private func postNotification(title: String, body: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        do {
            try await center.add(UNNotificationRequest(identifier: "RetentionUpgradeNotice", content: content, trigger: nil))
            return true
        } catch {
            logger.error("Retention notice notification failed")
            return false
        }
    }
}
