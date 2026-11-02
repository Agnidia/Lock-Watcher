//
//  CaptureMedia.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// What a trigger records.
enum CaptureOutputType: String, Codable, CaseIterable, Sendable {
    case photo
    case video
}

/// The local files of one incident record.
enum CaptureMedia: Sendable, Equatable {
    case photo(still: URL)
    /// `poster` is the record's still; nil when neither a frame nor a fallback photo could be taken.
    case video(movie: URL, poster: URL?)
}
