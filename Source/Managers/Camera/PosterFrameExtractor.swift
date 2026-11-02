//
//  PosterFrameExtractor.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import AVFoundation

/// Produces the still that represents a video record in history and notifications.
protocol PosterFrameExtracting: Sendable {
    func posterImage(from movie: URL) async -> sending NSImage?
}

/// Takes the frame at the middle of the movie.
struct AVPosterFrameExtractor: PosterFrameExtracting {
    func posterImage(from movie: URL) async -> sending NSImage? {
        let asset = AVURLAsset(url: movie)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let duration = try await asset.load(.duration)
            let (frame, _) = try await generator.image(at: CMTimeMultiplyByFloat64(duration, multiplier: 0.5))
            return NSImage(cgImage: frame, size: .zero)
        } catch {
            return nil
        }
    }
}
