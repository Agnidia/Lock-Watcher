//
//  QRCodeRenderer.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeRenderer {
    /// Integer scaling keeps module edges sharp; medium correction tolerates a camera at an angle.
    static func image(for text: String, scale: CGFloat = 10) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
