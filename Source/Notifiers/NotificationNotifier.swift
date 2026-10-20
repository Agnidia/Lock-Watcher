//
//  NotificationNotifier.swift
//
//  Created on 26.12.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import Foundation
import UserNotifications

/// `NotificationNotifier` is responsible for sending local notifications using the User Notifications framework.
/// These notifications alert the user when certain events (like detecting a potential threat) occur.
///
/// This class is `Sendable` because all stored properties are immutable and `Sendable`:
/// - `logger` conforms to `LogProtocol: Sendable`
final class NotificationNotifier: NotifierProtocol {
    // MARK: - Dependency injection

    /// A logger instance for logging various events and errors.
    private let logger: LogProtocol

    // MARK: - Initialiser

    /// Initializes a new `NotificationNotifier`.
    ///
    /// - Parameter logger: A logger instance. Defaults to a logger with the category `.notificationNotifier`.
    init(logger: LogProtocol = Log(category: .notificationNotifier)) {
        self.logger = logger
    }

    // MARK: - Public methods

    /// Registers the notifier with the provided settings.
    /// - Parameter settings: An instance conforming to `AppSettingsProtocol` containing app settings.
    func register(with settings: AppSettingsProtocol) {
        // This method is currently empty and can be populated as needed.
    }

    /// Sends a notification based on the provided `ThiefDto`.
    ///
    /// - Parameter thiefDto: An instance containing details about the event.
    /// - Throws: `NotifierError` if the notification cannot be sent.
    func send(_ thiefDto: ThiefDto) async throws {
        guard let media = thiefDto.media else {
            logger.error("wrong file path")
            throw NotifierError.invalidFilePath
        }

        let notificationCenter = UNUserNotificationCenter.current()

        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else {
            throw NotifierError.authenticationRequired
        }

        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            throw NotifierError.authenticationRequired
        }

        try await createNotification(thiefDto: thiefDto, media: media, to: notificationCenter)
    }

    // MARK: - Private helper methods

    /// Creates and sends a notification using the provided `ThiefDto` and `UNUserNotificationCenter`.
    ///
    /// - Parameters:
    ///   - thiefDto: An instance containing details about the event.
    ///   - media: The record's local files.
    ///   - notificationCenter: An instance of `UNUserNotificationCenter` to which the notification is to be added.
    private func createNotification(thiefDto: ThiefDto, media: CaptureMedia, to notificationCenter: UNUserNotificationCenter) async throws {
        let date = Date.defaultFormat.string(from: thiefDto.date)

        let content = UNMutableNotificationContent()
        content.title = String(format: NSLocalizedString("SnapshotAt", comment: ""), arguments: [date])
        content.body = thiefDto.triggerType.name
        content.sound = UNNotificationSound.default

        if let attachment = makeAttachment(for: media) {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: date, content: content, trigger: trigger)

        logger.debug("send: \(thiefDto)")

        try await notificationCenter.add(request)
    }

    /// The system moves an attachment's file into its own store, so it gets a copy and the record keeps its file.
    private func makeAttachment(for media: CaptureMedia) -> UNNotificationAttachment? {
        guard let source = MediaAttachmentPolicy.attachment(for: media, limitBytes: MediaAttachmentPolicy.notificationLimitBytes, logger: logger),
              let copy = temporaryCopy(of: source)
        else {
            return nil
        }

        do {
            return try UNNotificationAttachment(identifier: UUID().uuidString, url: copy, options: nil)
        } catch {
            logger.error("notification attachment rejected")
            try? FileManager.default.removeItem(at: copy.deletingLastPathComponent())
            return nil
        }
    }

    /// Copies `url` into its own folder under the temporary directory.
    func temporaryCopy(of url: URL) -> URL? {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let copy = folder.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: copy)
            return copy
        } catch {
            logger.error("notification attachment copy failed")
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
    }
}
