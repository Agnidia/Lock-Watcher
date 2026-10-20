//
//  USBListenerTests.swift
//
//  Created on 08.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import XCTest
@testable import Lock_Watcher

/// @test-required
@MainActor
final class USBListenerTests: XCTestCase {
    private let usbStick = VolumeFacts(isLocal: true, isInternal: false, isRemovable: true, isEjectable: true, deviceProtocol: "USB", deviceModel: "Flash Disk")
    private let externalDisk = VolumeFacts(isLocal: true, isInternal: false, isRemovable: false, isEjectable: true, deviceProtocol: "USB", deviceModel: "Portable SSD")
    private let internalDisk = VolumeFacts(isLocal: true, isInternal: true, isRemovable: false, isEjectable: false, deviceProtocol: "Apple Fabric", deviceModel: "APPLE SSD")
    private let smbShare = VolumeFacts(isLocal: false, isInternal: nil, isRemovable: false, isEjectable: true, deviceProtocol: nil, deviceModel: nil)
    /// Values observed for an attached .dmg; URL keys alone would read it as removable.
    private let diskImage = VolumeFacts(isLocal: true, isInternal: nil, isRemovable: true, isEjectable: true, deviceProtocol: "Virtual Interface", deviceModel: "Disk Image")

    // MARK: - Classifier

    func testClassifiesTheFiveVolumeKinds() {
        XCTAssertEqual(VolumeClassifier.classify(usbStick), .removable)
        XCTAssertEqual(VolumeClassifier.classify(externalDisk), .externalPhysical)
        XCTAssertEqual(VolumeClassifier.classify(internalDisk), .internal)
        XCTAssertEqual(VolumeClassifier.classify(smbShare), .network)
        XCTAssertEqual(VolumeClassifier.classify(diskImage), .diskImage)
    }

    func testOnlyRemovableAndExternalPhysicalFire() {
        XCTAssertTrue(VolumeClass.removable.firesUSBTrigger)
        XCTAssertTrue(VolumeClass.externalPhysical.firesUSBTrigger)
        XCTAssertFalse(VolumeClass.internal.firesUSBTrigger)
        XCTAssertFalse(VolumeClass.network.firesUSBTrigger)
        XCTAssertFalse(VolumeClass.diskImage.firesUSBTrigger)
    }

    func testDiskImageModelAloneIsEnough() {
        let facts = VolumeFacts(isLocal: true, isInternal: false, isRemovable: false, isEjectable: true, deviceProtocol: nil, deviceModel: "Disk Image")
        XCTAssertEqual(VolumeClassifier.classify(facts), .diskImage)
    }

    func testUnreadableFactsFailOpen() {
        XCTAssertEqual(VolumeClassifier.classify(VolumeFacts()), .externalPhysical)
    }

    func testRootVolumeReadsAsInternal() {
        let facts = VolumeFactsReader.read(volumeURL: URL(fileURLWithPath: "/"))
        XCTAssertEqual(facts.isLocal, true)
        XCTAssertEqual(VolumeClassifier.classify(facts), .internal)
    }

    // MARK: - Listener

    private func mountYields(_ facts: VolumeFacts?) async -> [TriggerType] {
        let center = NotificationCenter()
        let listener = USBListener(logger: LogMock(), notificationCenter: center, readFacts: { _ in facts ?? VolumeFacts() })
        let stream = listener.start()

        let userInfo: [AnyHashable: Any]? = facts == nil ? nil : [NSWorkspace.volumeURLUserInfoKey: URL(fileURLWithPath: "/Volumes/Test")]
        center.post(name: NSWorkspace.didMountNotification, object: nil, userInfo: userInfo)

        listener.stop()
        return await collectTriggers(stream)
    }

    func testRemovableMountYieldsUSBConnected() async {
        let triggers = await mountYields(usbStick)
        XCTAssertEqual(triggers, [.usbConnected])
    }

    func testExternalPhysicalMountYieldsUSBConnected() async {
        let triggers = await mountYields(externalDisk)
        XCTAssertEqual(triggers, [.usbConnected])
    }

    func testDiskImageNetworkAndInternalMountsYieldNothing() async {
        let image = await mountYields(diskImage)
        let share = await mountYields(smbShare)
        let internalVolume = await mountYields(internalDisk)
        XCTAssertEqual(image, [])
        XCTAssertEqual(share, [])
        XCTAssertEqual(internalVolume, [])
    }

    func testMountWithoutVolumeURLFailsOpen() async {
        let triggers = await mountYields(nil)
        XCTAssertEqual(triggers, [.usbConnected])
    }

    func testStartAndStopToggleIsRunning() {
        let listener = USBListener(logger: LogMock(), notificationCenter: NotificationCenter(), readFacts: { _ in VolumeFacts() })
        XCTAssertFalse(listener.isRunning)
        _ = listener.start()
        XCTAssertTrue(listener.isRunning)
        listener.stop()
        XCTAssertFalse(listener.isRunning)
    }
}

// MARK: - Source Info

// @source-file: Source/Listeners/USBListener.swift
