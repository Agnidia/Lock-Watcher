//
//  NotificationManager.swift
//
//  Created on 06.01.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import CoreLocation

/// The output channels a record can be sent through.
enum NotifierChannel: String, Sendable {
    case mail
    case iCloud
    case dropbox
    case notification
}

/// The result of one channel's delivery.
enum DeliveryOutcome: Sendable, Equatable {
    /// The remote copy is known to exist.
    case confirmed
    /// Sent, but the app cannot know whether it arrived (Mail is fire-and-forget).
    case unconfirmed
    case failed
}

/// Per-channel delivery results for one record.
struct DeliveryReport: Sendable, Equatable {
    static let empty = DeliveryReport(outcomes: [:])

    var outcomes: [NotifierChannel: DeliveryOutcome]

    /// True only when iCloud or Dropbox ran, every one that ran confirmed, and Mail was not used, because a Mail attachment must stay readable.
    var isRemoteUploadConfirmed: Bool {
        guard outcomes[.mail] == nil else { return false }
        let remote = [NotifierChannel.iCloud, .dropbox].compactMap { outcomes[$0] }
        return !remote.isEmpty && remote.allSatisfy { $0 == .confirmed }
    }
}

/// This protocol outlines the responsibilities and interface of the `NotificationManager` class.
protocol NotificationManagerProtocol: Sendable {
    /// Sends the record through every enabled channel and reports each channel's outcome.
    func send(_ thiefDto: ThiefDto) async -> DeliveryReport

    /// Complete the Dropbox authentication process.
    func completeDropboxAuthWith(url: URL) async -> String
}

/// The main class that orchestrates the sending of notifications through various channels.
///
/// - Note: `@unchecked Sendable` is required because:
///   - `AppSettingsProtocol` is not `Sendable` but is only read (never mutated) after initialization
///   - All notifiers are `Sendable` and thread-safe
final class NotificationManager: NotificationManagerProtocol, @unchecked Sendable {
    // MARK: - Dependency injection

    /// The manager uses settings to configure its behavior.
    /// - Note: Read-only after initialization, safe for concurrent access.
    private let settings: AppSettingsProtocol

    private let logger: LogProtocol

    // MARK: - Variables

    /// Different notifiers to send notifications through various channels.
    private let mailNotifier: any NotifierProtocol
    private let iCloudNotifier: any NotifierProtocol
    private let dropboxNotifier: any NotifierProtocol & DropboxNotifierProtocol
    private let notificationNotifier: any NotifierProtocol

    // MARK: - initialiser

    /// The manager is initialized with the given settings and registers some notifiers with these settings.
    init(settings: AppSettingsProtocol,
         mail: any NotifierProtocol = MailNotifier(),
         iCloud: any NotifierProtocol = ICloudNotifier(),
         dropbox: any NotifierProtocol & DropboxNotifierProtocol = DropboxNotifier(),
         notification: any NotifierProtocol = NotificationNotifier(),
         logger: LogProtocol = Log(category: .notificationManager))
    {
        self.settings = settings
        self.logger = logger
        mailNotifier = mail
        iCloudNotifier = iCloud
        dropboxNotifier = dropbox
        notificationNotifier = notification

        mailNotifier.register(with: settings)
        dropboxNotifier.register(with: settings)
    }

    // MARK: - public

    func send(_ thiefDto: ThiefDto) async -> DeliveryReport {
        await withTaskGroup(of: (NotifierChannel, DeliveryOutcome).self) { group in
            let mail = settings.sync.mailRecipient
            if !AppSettings.isMASBuild, settings.sync.isSendNotificationToMail, !mail.isEmpty {
                group.addTask {
                    await self.deliver(thiefDto, via: self.mailNotifier, channel: .mail, onSuccess: .unconfirmed)
                }
            }

            if settings.sync.isICloudSyncEnable {
                group.addTask {
                    await self.deliver(thiefDto, via: self.iCloudNotifier, channel: .iCloud, onSuccess: .confirmed)
                }
            }

            if settings.sync.isDropboxEnable {
                group.addTask {
                    await self.deliver(thiefDto, via: self.dropboxNotifier, channel: .dropbox, onSuccess: .confirmed)
                }
            }

            if settings.sync.isUseSnapshotLocalNotification {
                group.addTask {
                    await self.deliver(thiefDto, via: self.notificationNotifier, channel: .notification, onSuccess: .confirmed)
                }
            }

            var outcomes = [NotifierChannel: DeliveryOutcome]()
            for await (channel, outcome) in group {
                outcomes[channel] = outcome
            }
            return DeliveryReport(outcomes: outcomes)
        }
    }

    /// Completes the Dropbox authentication process.
    /// - Parameter url: The callback URL from Dropbox OAuth.
    /// - Returns: The display name of the authenticated user, or empty string on failure.
    func completeDropboxAuthWith(url: URL) async -> String {
        await dropboxNotifier.completeDropboxAuthWith(url: url)
    }

    // MARK: - private

    private func deliver(_ thiefDto: ThiefDto, via notifier: any NotifierProtocol, channel: NotifierChannel, onSuccess outcome: DeliveryOutcome) async -> (NotifierChannel, DeliveryOutcome) {
        do {
            try await notifier.send(thiefDto)
            return (channel, outcome)
        } catch {
            logger.error("\(channel.rawValue) delivery failed: \(Self.reason(for: error))")
            return (channel, .failed)
        }
    }

    /// A path-free failure reason; underlying errors can embed file paths, so only the case name is logged.
    private static func reason(for error: Error) -> String {
        guard let error = error as? NotifierError else { return "unexpected error" }
        return switch error {
        case .invalidFilePath: "invalidFilePath"
        case .invalidCloudURL: "invalidCloudURL"
        case .uploadFailed: "uploadFailed"
        case .authenticationRequired: "authenticationRequired"
        case .emptyData: "emptyData"
        case .missingConfiguration: "missingConfiguration"
        }
    }
}
