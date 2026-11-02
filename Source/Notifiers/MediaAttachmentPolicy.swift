//
//  MediaAttachmentPolicy.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Chooses the file a size-limited channel attaches for a record.
enum MediaAttachmentPolicy {
    /// Decimal megabytes, the smaller and safer reading of "20 MB".
    static let mailLimitBytes: Int64 = 20_000_000

    /// The system's movie attachment limit for a local notification.
    static let notificationLimitBytes: Int64 = 50_000_000

    /// The movie when its size is known and within `limitBytes`, otherwise the poster still.
    static func attachment(for media: CaptureMedia,
                           limitBytes: Int64,
                           fileSize: (URL) -> Int64? = MediaAttachmentPolicy.fileSize(of:),
                           logger: LogProtocol? = nil) -> URL?
    {
        switch media {
        case .photo(let still):
            return still
        case .video(let movie, let poster):
            if let size = fileSize(movie), size <= limitBytes {
                return movie
            }
            logger?.info("Movie is over the \(limitBytes)-byte attachment limit or unreadable; attaching the still instead")
            return poster
        }
    }

    static func fileSize(of url: URL) -> Int64? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
    }
}
