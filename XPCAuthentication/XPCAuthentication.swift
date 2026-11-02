//
//  XPCAuthentication.swift
//
//  Created on 28.03.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import os

/// `XPCAuthentication` manages the detection of authentication failure messages in the system log.
public final class XPCAuthentication: NSObject, XPCAuthenticationProtocol {
    private var outputPipe = Pipe()
    private var buildTask = Process()
    
    /// Detect authentication failure messages in the system log.
    ///
    /// This function scans the system logs from a given date for specific authentication failure messages. If a matching message is found, the `replyBlock` is invoked with `true`; otherwise, it's invoked with `false`.
    ///
    /// - Parameters:
    ///   - date: The date from which to begin scanning the system logs.
    ///   - replyBlock: A callback that receives a Boolean value indicating whether an authentication failure message was detected in the logs.
    public func detectedAuthenticationFailedFromDate(_ date: Date, _ replyBlock: @escaping (Bool) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        
        // Configure the process to run the `log` command with necessary arguments.
        buildTask.launchPath = "/usr/bin/log"
        buildTask.arguments = ["show",
                               "--predicate", "(eventMessage CONTAINS \"console domain: invalid credentials\") and (subsystem == \"com.apple.opendirectoryd\")",
                               "--style", "syslog",
                               "--start", "\(dateFormatter.string(from: date))"]
        
        os_log(.debug, "XPCAuthentication start listen from \(dateFormatter.string(from: date))")
        
        // Set the process's output to `outputPipe`.
        buildTask.standardOutput = outputPipe
        
        // Asynchronously wait for data to become available in the pipe.
        outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        
        // Observe for new data available in the pipe.
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable,
                                               object: outputPipe.fileHandleForReading,
                                               queue: nil)
        { [weak self] _ in
            if let output = self?.outputPipe.fileHandleForReading.availableData {
                // Convert the output data to a string and split it into lines.
                let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
                let lines = outputString.split(separator: "\n")
                
                // Determine if the log contains the authentication failure message.
                let detectedAuthenticationFailed = lines.count > 1
                
                os_log(.debug, "XPCAuthentication lines \(lines)")
                
                replyBlock(detectedAuthenticationFailed)
            }
        }
        
        // Launch the process.
        buildTask.launch()
        
        // Wait until the process exits.
        buildTask.waitUntilExit()
    }
}
