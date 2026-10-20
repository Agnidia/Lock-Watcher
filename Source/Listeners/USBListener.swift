//
//  USBListener.swift
//
//  Created on 09.01.2021.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Cocoa
import DiskArbitration
import Foundation

/// The kind of storage behind a mounted volume.
enum VolumeClass: Sendable, Equatable {
    case removable
    case externalPhysical
    case `internal`
    case network
    case diskImage

    /// Only physical media plugged into the Mac count as a USB attach.
    var firesUSBTrigger: Bool {
        self == .removable || self == .externalPhysical
    }
}

/// Mount facts read from URL resource values and DiskArbitration; `nil` means unreadable.
struct VolumeFacts: Sendable, Equatable {
    var isLocal: Bool?
    var isInternal: Bool?
    var isRemovable: Bool?
    var isEjectable: Bool?
    var deviceProtocol: String?
    var deviceModel: String?
}

enum VolumeClassifier {
    /// DiskArbitration's device protocol and model for volumes backed by a disk image.
    static let diskImageMarker = "Disk Image"

    /// Unknown facts fall through to `.externalPhysical`, so a failed read still fires the trigger.
    static func classify(_ facts: VolumeFacts) -> VolumeClass {
        if facts.isLocal == false {
            return .network
        }
        if facts.deviceProtocol == diskImageMarker || facts.deviceModel == diskImageMarker {
            return .diskImage
        }
        if facts.isInternal == true {
            return .internal
        }
        if facts.isRemovable == true {
            return .removable
        }
        return .externalPhysical
    }
}

enum VolumeFactsReader {
    static func read(volumeURL: URL) -> VolumeFacts {
        var facts = VolumeFacts()

        let keys: Set<URLResourceKey> = [.volumeIsLocalKey, .volumeIsInternalKey, .volumeIsRemovableKey, .volumeIsEjectableKey]
        if let values = try? volumeURL.resourceValues(forKeys: keys) {
            facts.isLocal = values.volumeIsLocal
            facts.isInternal = values.volumeIsInternal
            facts.isRemovable = values.volumeIsRemovable
            facts.isEjectable = values.volumeIsEjectable
        }

        (facts.deviceProtocol, facts.deviceModel) = deviceDescription(volumeURL: volumeURL)
        return facts
    }

    /// URL resource values have no disk-image key, so the device protocol and model come from
    /// DiskArbitration; the whole disk is read when the volume's own disk lacks both.
    private static func deviceDescription(volumeURL: URL) -> (String?, String?) {
        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, volumeURL as CFURL)
        else {
            return (nil, nil)
        }

        let volumeDevice = deviceDescription(disk: disk)
        guard volumeDevice.0 == nil, volumeDevice.1 == nil, let wholeDisk = DADiskCopyWholeDisk(disk) else {
            return volumeDevice
        }
        return deviceDescription(disk: wholeDisk)
    }

    private static func deviceDescription(disk: DADisk) -> (String?, String?) {
        guard let description = DADiskCopyDescription(disk) as? [String: Any] else { return (nil, nil) }
        let deviceProtocol = description[kDADiskDescriptionDeviceProtocolKey as String] as? String
        let deviceModel = description[kDADiskDescriptionDeviceModelKey as String] as? String
        return (deviceProtocol, deviceModel?.trimmingCharacters(in: .whitespaces))
    }
}

/// `USBListener` observes volume mounts and emits `.usbConnected` only for removable or
/// external physical media.
///
/// This class is `@MainActor` isolated through `BaseListenerProtocol` conformance,
/// ensuring all state mutations occur on the main thread.
final class USBListener: NSObject, BaseListenerProtocol {
    // MARK: - Dependency injection

    /// Logger instance used for recording and debugging.
    private let logger: LogProtocol

    /// NotificationCenter that posts `didMountNotification`.
    private let notificationCenter: NotificationCenter

    private let readFacts: @MainActor (URL) -> VolumeFacts

    // MARK: - Variables

    /// Indicates if the listener is currently monitoring USB mount events.
    private(set) var isRunning: Bool = false

    /// Continuation for the AsyncStream to yield events.
    private var continuation: AsyncStream<ListenerEvent>.Continuation?

    // MARK: - Initializer

    init(logger: LogProtocol = Log(category: .usbListener),
         notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
         readFacts: @escaping @MainActor (URL) -> VolumeFacts = VolumeFactsReader.read)
    {
        self.logger = logger
        self.notificationCenter = notificationCenter
        self.readFacts = readFacts
    }

    // MARK: - Public Methods

    /// Starts monitoring for USB mount events.
    /// - Returns: An AsyncStream that emits events when USB mount is detected.
    func start() -> AsyncStream<ListenerEvent> {
        logger.debug("USBListener Started")

        return AsyncStream { continuation in
            self.continuation = continuation
            self.isRunning = true

            self.notificationCenter.addObserver(
                self,
                selector: #selector(self.receiveUSBNotification),
                name: NSWorkspace.didMountNotification,
                object: nil
            )

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.cleanup()
                }
            }
        }
    }

    /// Stops the listener from monitoring USB mount events.
    func stop() {
        logger.debug("USBListener Stopped")
        continuation?.finish()
        cleanup()
    }

    // MARK: - Private Methods

    private func cleanup() {
        isRunning = false
        continuation = nil
        notificationCenter.removeObserver(self, name: NSWorkspace.didMountNotification, object: nil)
    }

    /// A notification without a volume URL classifies as `.externalPhysical` and fires.
    @objc
    private func receiveUSBNotification(_ notification: Notification) {
        let facts = (notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL).map(readFacts) ?? VolumeFacts()
        let volumeClass = VolumeClassifier.classify(facts)
        logger.info("Volume mounted: \(volumeClass)")

        guard volumeClass.firesUSBTrigger else { return }
        continuation?.yield((.onUSBConnectionListener, .usbConnected))
    }
}

// MARK: - Test Info

// @test-file: Tests/Listeners/USBListenerTests.swift
