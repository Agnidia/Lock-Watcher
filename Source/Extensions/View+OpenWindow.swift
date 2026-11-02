//
//  View+OpenWindow.swift
//
//  Created on 26.01.2022.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

extension View {
    /// Presents the current SwiftUI view inside a new `NSWindow`.
    ///
    /// This method creates a new `NSWindow`, sets the provided view as its root content, and then displays it.
    ///
    /// - Parameters:
    ///   - title: The title string to be used as the window's title.
    ///   - sender: The object that initiates the opening of the window. This can be used to further customize or control the action based on the sender. Usually passed as `nil` when not needed.
    /// - Returns: An `NSWindow` object representing the created window.
    ///
    /// - Usage:
    /// ```swift
    /// Text("Hello, World!")
    ///     .openInWindow(title: "Greetings", sender: nil)
    /// ```
    /// The above example will open a new window with the title "Greetings" and display a `Text` view with the content "Hello, World!".
    ///
    @discardableResult
    func openInWindow(title: String, sender: Any?) -> NSWindow {
        // Create a new window with the hosting controller as its content.
        let controller = NSHostingController(rootView: self)
        let window = NSWindow(contentViewController: controller)

        // Define the window's style, making it closable and titled.
        window.styleMask = [.closable, .titled]

        // Set the hosting controller as the window's content view controller.
        window.contentViewController = controller

        // Set the window's title.
        window.title = title

        // Ensure the window's resources are released when it's closed.
        window.isReleasedWhenClosed = true

        // Force layout to calculate SwiftUI content size before centering.
        controller.view.layoutSubtreeIfNeeded()
        window.setContentSize(controller.view.fittingSize)

        // Center the window on screen.
        window.center()

        // Bring the window to the front and activate it.
        window.makeKeyAndOrderFront(sender)

        return window
    }
}
