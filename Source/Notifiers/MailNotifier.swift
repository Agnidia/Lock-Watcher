//
//  MailNotifier.swift
//
//  Created on 28.03.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreLocation
import Foundation

/// A service responsible for handling and sending mail notifications.
///
/// The `MailNotifier` uses the XPCMail service to interact with the Mail app
/// and sends notifications or alerts based on the information provided in the `ThiefDto` data object.
/// The mails are sent using the default mail account configured in the Mail app.
///
/// - Note: `@unchecked Sendable` is required because:
///   - `NSXPCConnection` is not marked `Sendable` but XPC is inherently thread-safe
///   - `AppSettingsProtocol` reference is set once during `register()` and only read thereafter
final class MailNotifier: NotifierProtocol, @unchecked Sendable {
    // MARK: - Dependency injection

    /// Logger instance responsible for capturing and logging events or errors.
    private let logger: LogProtocol

    // MARK: - Variables

    /// The application settings used to configure the mail notifier.
    /// - Note: Set once during `register()` and only read thereafter.
    private nonisolated(unsafe) var settings: AppSettingsProtocol!

    /// Constant identifier for the XPCMail service.
    private let kServiceName = "com.igrsoft.XPCMail"

    /// An XPC connection responsible for interprocess communication with the XPCMail service.
    /// - Note: XPC connections are inherently thread-safe.
    private lazy var connection: NSXPCConnection = {
        let connection = NSXPCConnection(serviceName: kServiceName)
        connection.remoteObjectInterface = NSXPCInterface(with: XPCMailProtocol.self)
        connection.resume()

        connection.interruptionHandler = { [weak self] in
            self?.logger.error("XPCMail interrupted")
        }
        connection.invalidationHandler = { [weak self] in
            self?.logger.error("XPCMail invalidated")
        }

        return connection
    }()

    /// The remote service object that allows for communication with the XPCMail service.
    /// - Note: XPC proxies are thread-safe.
    private lazy var service: XPCMailProtocol = {
        connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("Received error: \(error.localizedDescription)")
        } as! XPCMailProtocol
    }()

    // MARK: - Initializer

    /// Initializes a new instance of the `MailNotifier` with the provided logger or a default logger.
    ///
    /// - Parameter logger: An optional logger instance for capturing and logging events.
    init(logger: LogProtocol = Log(category: .mailNotifier)) {
        self.logger = logger
    }

    // MARK: - Public methods

    /// Registers the notifier with the provided application settings.
    ///
    /// - Parameter settings: The application settings to configure the mail notifier.
    func register(with settings: AppSettingsProtocol) {
        self.settings = settings
    }

    /// Sends a mail notification based on the provided `ThiefDto` information.
    ///
    /// This function communicates with the XPCMail service to dispatch the mail; a movie over the size limit is replaced by the still.
    ///
    /// - Parameter thiefDto: The data object containing the details to be included in the mail.
    /// - Throws: `NotifierError` if required configuration is missing.
    func send(_ thiefDto: ThiefDto) async throws {
        guard let media = thiefDto.media,
              let filePath = MediaAttachmentPolicy.attachment(for: media, limitBytes: MediaAttachmentPolicy.mailLimitBytes, logger: logger)?.path
        else {
            logger.error("wrong file path")
            throw NotifierError.invalidFilePath
        }

        let mail = settings.sync.mailRecipient
        guard !mail.isEmpty else {
            logger.error("missed mail address")
            throw NotifierError.missingConfiguration("mailRecipient")
        }

        logger.debug("send: \(thiefDto)")

        // XPC service is fire-and-forget, no async response needed
        service.sendMail(mail, coordinates: thiefDto.coordinate ?? kCLLocationCoordinate2DInvalid, attachment: filePath)
    }
}
