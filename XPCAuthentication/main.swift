//
//  main.swift
//
//  Created on 28.03.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// `XPCAuthenticationDelegate` is a delegate that manages new incoming XPC connections. It sets up the interface and object to be exposed over the connection.
final class XPCAuthenticationDelegate: NSObject, NSXPCListenerDelegate {
    /// Decides whether or not to accept a new XPC connection.
    ///
    /// When a new connection request is received, this method sets up the exported object and its interface.
    /// The connection is then resumed to start receiving messages.
    ///
    /// - Parameters:
    ///   - listener: The active `NSXPCListener` that received a new connection.
    ///   - newConnection: The new incoming `NSXPCConnection`.
    ///
    /// - Returns: A boolean indicating whether the new connection should be accepted. Always returns true in this implementation.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Create an instance of the object that will handle the XPC requests.
        let exportedObject = XPCAuthentication()
        
        // Set up the XPC interface to expose the methods of `XPCAuthenticationProtocol`.
        newConnection.exportedInterface = NSXPCInterface(with: XPCAuthenticationProtocol.self)
        
        // Set the object to handle requests.
        newConnection.exportedObject = exportedObject
        
        // Resume the connection to start receiving messages.
        newConnection.resume()
        
        // Accept the connection.
        return true
    }
}

// Set up the XPC service's main listener with the delegate.
let delegate = XPCAuthenticationDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate

// Resume the listener to start accepting new connections.
listener.resume()
