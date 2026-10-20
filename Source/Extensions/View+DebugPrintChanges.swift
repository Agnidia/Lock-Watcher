//
//  View+DebugPrintChanges.swift
//
//  Created on 01.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

extension View {
    /// Logs view changes during DEBUG builds using SwiftUI's `_printChanges()`.
    ///
    /// This method wraps the conditional compilation for `_printChanges()` so that
    /// view bodies don't need to include `#if DEBUG` blocks.
    ///
    /// Usage in body:
    /// ```swift
    /// var body: some View {
    ///     let _ = Self.logViewChanges()
    ///     VStack { ... }
    /// }
    /// ```
    @inline(__always)
    static func logViewChanges() {
        #if DEBUG
        _printChanges()
        #endif
    }
}
