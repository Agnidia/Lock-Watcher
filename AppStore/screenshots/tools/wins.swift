//
//  wins.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreGraphics
import Foundation

/// One line per on-screen window of the capture build: id layer x y w h name
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    let want = CommandLine.arguments.count > 1 ? Int32(CommandLine.arguments[1]) : nil
    guard let pid = w[kCGWindowOwnerPID as String] as? Int32, want == nil || pid == want else { continue }
    let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let n = { (k: String) -> Int in Int((b[k] as? NSNumber)?.doubleValue ?? 0) }
    print(w[kCGWindowNumber as String] ?? 0, w[kCGWindowLayer as String] ?? 0, n("X"), n("Y"), n("Width"), n("Height"), w[kCGWindowName as String] ?? "-")
}
