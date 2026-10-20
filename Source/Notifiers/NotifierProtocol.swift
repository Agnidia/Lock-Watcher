//
//  NotifierProtocol.swift
//
//  Created on 05.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Errors that can occur during notification sending.
enum NotifierError: Error, Sendable {
    /// The file path in ThiefDto is invalid or nil.
    case invalidFilePath

    /// The cloud service URL is unavailable.
    case invalidCloudURL(String)

    /// The upload or send operation failed.
    case uploadFailed(Error)

    /// Authentication is required before sending.
    case authenticationRequired

    /// The image data is empty or invalid.
    case emptyData

    /// Missing required configuration (e.g., mail recipient).
    case missingConfiguration(String)
}

/// Defines the behavior for a notifier.
///
/// A notifier is responsible for handling and dispatching notifications based on
/// certain events or triggers in the application. This could be for logging, alerts, or other notifications.
protocol NotifierProtocol {
    /// Registers the notifier with the provided application settings.
    ///
    /// This function initializes or sets up the notifier based on the configurations provided in the settings.
    ///
    /// - Parameter settings: The application settings to configure the notifier.
    func register(with settings: AppSettingsProtocol)

    /// Sends a notification based on the provided `ThiefDto` information.
    ///
    /// This function is used to dispatch a notification when a certain event or trigger is detected.
    ///
    /// - Parameter thiefDto: The data object containing the details of the event or trigger.
    /// - Throws: `NotifierError` if the notification fails to send.
    func send(_ thiefDto: ThiefDto) async throws
}
