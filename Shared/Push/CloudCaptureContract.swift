//
//  CloudCaptureContract.swift
//
//  Created on 13.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Where the Mac saves captures in iCloud and which of them the companion lists. The push payload names a capture by file name only, so both apps must agree on the folder and the image types.
public enum CloudCaptureContract {
    /// Folder of the iCloud container that holds the captures. The companion reads the same folder through the documents scope of its metadata query.
    public static let folderName = "Documents"

    /// Lowercase extensions of the still images the companion shows; videos are saved as `.mov` and are not listed.
    public static let stillExtensions: Set<String> = ["jpeg", "jpg", "png", "heic"]
}
