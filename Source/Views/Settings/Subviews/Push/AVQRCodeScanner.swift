//
//  AVQRCodeScanner.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import AVFoundation
import SwiftUI

enum QRScannerError: Error, Sendable {
    case cameraUnavailable
}

/// Camera QR reader; only decoded strings cross isolation.
protocol QRCodeScanning: Sendable {
    /// Starts the camera; the stream yields every decoded QR string until `stop()`.
    func codes() async throws -> AsyncStream<String>
    func stop() async
    @MainActor
    func makePreviewLayer() -> CALayer?
}

/// Owns the capture session on its own serial queue, because `startRunning` and `stopRunning` block and must stay off the main thread.
actor AVQRCodeScanner: QRCodeScanning {
    private let queue = DispatchSerialQueue(label: "com.igrsoft.Lock-Watcher.qr-scanner")

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    /// Shared with the preview layer only; `AVCaptureVideoPreviewLayer` may attach to a session that another queue drives.
    private nonisolated(unsafe) let session = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private var delegate: MetadataDelegate?
    private var isConfigured = false

    func codes() throws -> AsyncStream<String> {
        if !isConfigured {
            try configure()
        }
        delegate?.continuation.finish()
        let (stream, continuation) = AsyncStream<String>.makeStream(bufferingPolicy: .bufferingNewest(4))
        let delegate = MetadataDelegate(continuation: continuation)
        self.delegate = delegate
        output.setMetadataObjectsDelegate(delegate, queue: queue)
        if !session.isRunning {
            session.startRunning()
        }
        return stream
    }

    func stop() {
        output.setMetadataObjectsDelegate(nil, queue: nil)
        delegate?.continuation.finish()
        delegate = nil
        if session.isRunning {
            session.stopRunning()
        }
    }

    @MainActor
    func makePreviewLayer() -> CALayer? {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    /// A busy or missing camera (CameraSnap may hold it) throws instead of crashing.
    private func configure() throws {
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else {
            throw QRScannerError.cameraUnavailable
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw QRScannerError.cameraUnavailable
        }
        session.addInput(input)
        session.addOutput(output)
        guard output.availableMetadataObjectTypes.contains(.qr) else {
            throw QRScannerError.cameraUnavailable
        }
        output.metadataObjectTypes = [.qr]
        isConfigured = true
    }
}

/// AVFoundation calls it on the scanner queue only.
private final class MetadataDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let continuation: AsyncStream<String>.Continuation

    init(continuation: AsyncStream<String>.Continuation) {
        self.continuation = continuation
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for case let code as AVMetadataMachineReadableCodeObject in metadataObjects {
            if let value = code.stringValue {
                continuation.yield(value)
            }
        }
    }
}

struct QRScannerPreview: NSViewRepresentable {
    let scanner: any QRCodeScanning

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        if let preview = scanner.makePreviewLayer() {
            preview.frame = view.bounds
            preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            view.layer?.addSublayer(preview)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Test Info

// @test-file: Tests/ViewModels/PushPairingViewModelTests.swift
