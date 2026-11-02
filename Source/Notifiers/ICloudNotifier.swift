//
//  ICloudNotifier.swift
//
//  Created on 10.08.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import CoreLocation

/// A service responsible for handling and sending image notifications to iCloud.
///
/// The `iCloudNotifier` interacts with the iCloud and sends an image captured from the `ThiefDto`
/// data object to the user's iCloud Documents folder.
///
/// This class is `Sendable` because all stored properties are immutable and `Sendable`:
/// - `logger` conforms to `LogProtocol: Sendable`
/// - `documentsFolderName` is an immutable `String`
final class ICloudNotifier: NotifierProtocol, Sendable {
    // MARK: - Dependency injection

    /// Logger instance responsible for capturing and logging events or errors.
    private let logger: LogProtocol

    // MARK: - Variables

    /// Name of the iCloud directory where images are saved.
    /// Default is "Documents".
    private let documentsFolderName = "Documents"

    // MARK: - Initializer

    /// Initializes a new instance of the `ICloudNotifier` with the provided logger or a default logger.
    ///
    /// - Parameter logger: An optional logger instance for capturing and logging events.
    init(logger: LogProtocol = Log(category: .iCloudNotifier)) {
        self.logger = logger
    }

    // MARK: - Public methods

    /// Registers the notifier with the provided application settings.
    ///
    /// - Parameter settings: The application settings to configure the iCloud notifier.
    func register(with settings: AppSettingsProtocol) {
        // This method is left blank for future settings integrations.
    }

    /// Copies the movie of a video record, then writes the still annotated with the record's details.
    ///
    /// - Throws: `NotifierError` if a file fails to save.
    func send(_ thiefDto: ThiefDto) async throws {
        guard let media = thiefDto.media else {
            logger.error("wrong file path")
            throw NotifierError.invalidFilePath
        }

        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent(documentsFolderName) else {
            logger.error("wrong iCloud url")
            throw NotifierError.invalidCloudURL("iCloud")
        }

        logger.debug("send: \(thiefDto)")

        if case .video(let movie, _) = media {
            do {
                try FileManager.default.copyItem(at: movie, to: iCloudURL.appendingPathComponent(movie.lastPathComponent))
            } catch {
                logger.error("movie copy failed")
                throw NotifierError.uploadFailed(error)
            }
        }

        guard let localURL = thiefDto.filePath, var image = thiefDto.snapshot else {
            if case .photo = media {
                throw NotifierError.emptyData
            }
            return
        }

        let info = thiefDto.description()
        if !info.isEmpty {
            image = image.imageWithText(text: info) ?? image
        }

        let data = image.jpegData(quality: thiefDto.compressionFactor)
        guard !data.isEmpty else {
            throw NotifierError.emptyData
        }

        do {
            try data.write(to: iCloudURL.appendingPathComponent(localURL.lastPathComponent))
        } catch {
            logger.error("still write failed")
            throw NotifierError.uploadFailed(error)
        }
    }
}
