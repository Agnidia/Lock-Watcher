//
//  NSImage+Text.swift
//
//  Created on 10.08.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import CoreGraphics

extension NSImage {
    /// Adds text to the top left corner of the image.
    ///
    /// This method overlays a given text on the top left corner of the image. Customizations include the font size and color of the text.
    ///
    /// - Parameters:
    ///   - text: The text to overlay on the image.
    ///   - fontSize: The size of the font for the text. Default is `12`.
    ///   - color: The color of the text. Default is semi-transparent red (`red` with alpha component `0.8`).
    ///
    /// - Returns: An `NSImage` with the overlaid text. Returns the original image if there's an error in processing.
    func imageWithText(text: String, fontSize: CGFloat = 12, color: NSColor = .red.withAlphaComponent(0.8)) -> NSImage? {
        let imageSize = size
        let imageRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
        
        // Adjust font size based on the screen's scale factor (Retina support).
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 1
        let font = NSFont.boldSystemFont(ofSize: fontSize * scaleFactor)
        let textRect = CGRect(x: 5, y: 5, width: imageRect.size.width - 5, height: imageRect.size.height - 5)
        
        // Define text attributes: font, color, and paragraph style.
        let textStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        let textFontAttributes: [NSAttributedString.Key : Any] = [.font: font, .foregroundColor: color, .paragraphStyle: textStyle]
        
        // Convert NSImage to CGImage
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return self
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        bitmapRep.size = imageRect.size
        
        // Create a new image and draw the original image and the text onto it.
        let image = NSImage(size: imageRect.size)
        image.addRepresentation(bitmapRep)
        
        image.lockFocus()
        draw(in: imageRect)
        text.draw(in: textRect, withAttributes: textFontAttributes)
        image.unlockFocus()
        
        return image
    }
}
