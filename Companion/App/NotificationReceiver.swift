//
//  NotificationReceiver.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import UserNotifications

/// The delegate uses the completion-handler methods and calls them on the main actor: UIKit finishes a notification response by updating the app snapshot, which asserts on the main thread, and an async delegate method completes on a background task thread.
final class NotificationReceiver: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private let sink: @MainActor @Sendable ([ReceivedAlert], _ opened: Bool) -> Void

    init(sink: @escaping @MainActor @Sendable ([ReceivedAlert], _ opened: Bool) -> Void) {
        self.sink = sink
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let alert = Self.alert(from: notification)
        nonisolated(unsafe) let finish = completionHandler
        Task { @MainActor in
            sink([alert], false)
            finish([.banner, .list, .sound])
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let alert = Self.alert(from: response.notification)
        nonisolated(unsafe) let finish = completionHandler
        Task { @MainActor in
            sink([alert], true)
            finish()
        }
    }

    /// Alerts that arrived while the app was closed; without a service extension this pull is the only way to list them.
    func deliveredAlerts() async -> [ReceivedAlert] {
        await UNUserNotificationCenter.current().deliveredNotifications().map(Self.alert(from:))
    }

    static func alert(from notification: UNNotification) -> ReceivedAlert {
        let content = notification.request.content
        return ReceivedAlert.parse(identifier: notification.request.identifier,
                                   userInfo: content.userInfo,
                                   title: content.title,
                                   body: content.body,
                                   deliveredAt: notification.date)
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
