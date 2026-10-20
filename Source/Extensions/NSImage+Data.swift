//
//  NSImage+Data.swift
//
//  Created on 30.06.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit

extension NSImage {
    /// Represents the `NSImage` as JPEG data using the default high quality (75%).
    ///
    /// - Returns: Data representation of the image in JPEG format. If the conversion fails, it returns an empty Data instance.
    var jpegData: Data {
        jpegData(quality: SnapshotQuality.high.compressionFactor)
    }

    /// Converts the `NSImage` to JPEG data with the specified compression quality.
    ///
    /// - Parameter quality: A value between 0.0 (maximum compression) and 1.0 (lossless) controlling JPEG quality.
    /// - Returns: Data representation of the image in JPEG format. If the conversion fails, it returns an empty Data instance.
    func jpegData(quality: CGFloat) -> Data {
        guard let tiffData = tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData) else {
            return Data()
        }

        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            return Data()
        }

        return data
    }
}
