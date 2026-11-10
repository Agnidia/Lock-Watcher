//
//  NotificationReceiver.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import UserNotifications

/// UserNotifications calls its delegate off the main actor with non-Sendable values, so each callback parses to `ReceivedAlert` before the main-actor hop.
final class NotificationReceiver: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private let sink: @MainActor @Sendable ([ReceivedAlert], _ opened: Bool) -> Void

    init(sink: @escaping @MainActor @Sendable ([ReceivedAlert], _ opened: Bool) -> Void) {
        self.sink = sink
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let alert = Self.alert(from: notification)
        await sink([alert], false)
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let alert = Self.alert(from: response.notification)
        await sink([alert], true)
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
