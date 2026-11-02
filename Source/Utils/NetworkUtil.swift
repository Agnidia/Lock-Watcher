//
//  NetworkUtil.swift
//
//  Created on 03.01.2022.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import SimpleTracer

/// `NetworkUtilProtocol` provides an interface for networking utilities such as fetching IP addresses and performing trace routes.
protocol NetworkUtilProtocol {
    /// Fetches the device's public IP address.
    /// - Returns: The public IP address or an empty string if fetching fails.
    func getIFAddresses() -> String
    
    /// Executes a trace route to the specified host.
    /// - Parameters:
    ///   - host: The IP or domain address to trace.
    ///   - complete: A closure executed upon completion of the trace, returning the trace's result as a string.
    func getTraceRoute(host: String, complete: @escaping Commons.StringClosure)
}

/// `NetworkUtil` provides utilities for network-related tasks, such as fetching the device's IP address and performing trace routes.
public final class NetworkUtil: NetworkUtilProtocol {
    // MARK: - Dependency injection
    
    /// A logger instance for logging various events and errors.
    private var logger: LogProtocol
    
    // MARK: - Variables
    
    /// An instance of `SimpleTracer` to handle trace routing.
    private var simpleTracer: SimpleTracer?
    
    // MARK: - Initialiser
    
    /// Initializes a new `NetworkUtil`.
    ///
    /// - Parameter logger: A logger instance. Defaults to a logger with the category `.networkUtil`.
    init(logger: LogProtocol = Log(category: .networkUtil)) {
        self.logger = logger
    }
    
    deinit {
        simpleTracer?.stop()
    }
    
    // MARK: - Public methods
    
    /// Fetch the device's public IP address from ipify.org.
    ///
    /// - Returns: The public IP address or an empty string if fetching fails.
    func getIFAddresses() -> String {
        var publicIP = ""
        do {
            try publicIP = String(contentsOf: URL(string: "https://api.ipify.org")!, encoding: .utf8)
            publicIP = publicIP.trimmingCharacters(in: CharacterSet.whitespaces)
        } catch {
            logger.error("Network Error: \(error.localizedDescription)")
        }
        
        return publicIP
    }
    
    /// Executes a trace route to the specified host and returns the result.
    ///
    /// - Parameters:
    ///   - host: The IP or domain address to trace.
    ///   - complete: A closure executed upon completion of the trace, returning the trace's result as a string.
    func getTraceRoute(host: String, complete: @escaping Commons.StringClosure) {
        var traceRoute = ""
        
        // SimpleTracer keeps no shared instance, so the tracer lives only as long as this reference.
        simpleTracer?.stop()
        simpleTracer = SimpleTracer(host: host, maxTraceTTL: 16) { result in
            switch result {
            case .finished(_, let ip, _):
                traceRoute += "\(ip)}"
                complete(traceRoute)
            case .failed(let error):
                traceRoute += "\(error)}"
                complete(traceRoute)
            case .start(_, let ip, _):
                traceRoute += "Trace route: { \(ip)\n"
            case .router(_, let ip, _):
                traceRoute += "- \(ip)\n"
            case .routerDoesNotRespond:
                traceRoute += "- * * *\n"
            }
        }
        simpleTracer?.start()
    }
}
