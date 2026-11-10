//
//  CloudPhotoImageDecoder.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Decodes files that arrived through iCloud, so it treats them as untrusted: known still formats only and a bounded bitmap.
enum CloudPhotoImageDecoder {
    /// Above a 6K display capture (20.4 MP) and a 12 MP camera frame; a format ImageIO cannot subsample still decodes to at most about 128 MB.
    static let maxSourcePixels = 32_000_000

    static let stillTypes = [UTType.jpeg, .png, .heic].map(\.identifier)
    private static let stillTypeSet = Set(stillTypes)

    /// ImageIO accepts the process-wide list only once, so the first status is kept and every later call reports it.
    private static let processWideRestriction: Bool = {
        if #available(iOS 17.2, *) {
            return CGImageSourceSetAllowableTypes(stillTypes as CFArray) == OSStatus(noErr)
        }
        return false
    }()

    /// Keeps every other ImageIO parser out of reach of a crafted iCloud file. Call at launch, before the first decode; false before iOS 17.2.
    @discardableResult
    static func restrictProcessWideTypes() -> Bool {
        processWideRestriction
    }

    /// Returns nil for anything that is not a plausible still. Thumbnail decoding keeps memory proportional to `maxPixelSize`, not to the source.
    @concurrent
    static func decode(_ data: Data, maxPixelSize: Int, sourcePixelLimit: Int = CloudPhotoImageDecoder.maxSourcePixels) async -> CGImage? {
        guard maxPixelSize > 0,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source), stillTypeSet.contains(type as String),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= sourcePixelLimit / height else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CloudPhotoLibraryTests.swift
