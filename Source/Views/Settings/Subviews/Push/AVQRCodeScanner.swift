//
//  AVQRCodeScanner.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AppKit
import AVFoundation
import os
import SwiftUI
import Vision

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
    private static let log = Logger(subsystem: "com.igrsoft.Lock-Watcher", category: "qr-scanner")
    private let queue = DispatchSerialQueue(label: "com.igrsoft.Lock-Watcher.qr-scanner")

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    /// Shared with the preview layer only; `AVCaptureVideoPreviewLayer` may attach to a session that another queue drives.
    private nonisolated(unsafe) let session = AVCaptureSession()
    /// The preview is created before `codes()` adds the camera input, and its connection exists only after that, so `configure()` mirrors it then.
    private nonisolated(unsafe) weak var previewLayer: AVCaptureVideoPreviewLayer?
    private let output = AVCaptureVideoDataOutput()
    private var delegate: FrameDelegate?
    private var isConfigured = false

    func codes() throws -> AsyncStream<String> {
        if !isConfigured {
            try configure()
        }
        delegate?.continuation.finish()
        let (stream, continuation) = AsyncStream<String>.makeStream(bufferingPolicy: .bufferingNewest(4))
        let delegate = FrameDelegate(continuation: continuation)
        self.delegate = delegate
        output.setSampleBufferDelegate(delegate, queue: queue)
        if !session.isRunning {
            session.startRunning()
        }
        return stream
    }

    func stop() {
        output.setSampleBufferDelegate(nil, queue: nil)
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
        previewLayer = layer
        mirrorPreview()
        return layer
    }

    /// Shows the camera like a mirror; the frames sent to Vision stay unmirrored, so the QR still decodes.
    private nonisolated func mirrorPreview() {
        guard let connection = previewLayer?.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }

    /// A busy or missing camera (CameraSnap may hold it) throws instead of crashing.
    private func configure() throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            Self.log.error("QR scanner: no video device")
            throw QRScannerError.cameraUnavailable
        }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            Self.log.error("QR scanner: input failed, code \((error as NSError).code, privacy: .public)")
            throw QRScannerError.cameraUnavailable
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddInput(input), session.canAddOutput(output) else {
            Self.log.error("QR scanner: session rejected input or output")
            throw QRScannerError.cameraUnavailable
        }
        session.addInput(input)
        session.addOutput(output)
        output.alwaysDiscardsLateVideoFrames = true
        mirrorPreview()
        isConfigured = true
    }
}

/// Decodes frames with Vision because `AVCaptureMetadataOutput` offers no QR type on some Macs. AVFoundation calls it on the scanner queue only.
private final class FrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// Decoding every frame wastes battery; a QR held in front of the camera stays long enough for a few reads per second.
    private static let minInterval: TimeInterval = 0.25

    let continuation: AsyncStream<String>.Continuation
    private var lastScan = Date.distantPast

    init(continuation: AsyncStream<String>.Continuation) {
        self.continuation = continuation
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastScan) >= Self.minInterval,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        lastScan = now

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        guard (try? VNImageRequestHandler(cvPixelBuffer: pixels).perform([request])) != nil else { return }
        for case let barcode in request.results ?? [] {
            if let value = barcode.payloadStringValue {
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

#if DEBUG
    // The stub has no camera, so the preview shows the empty scanner surface.
    #Preview("QR scanner") {
        QRScannerPreview(scanner: StubQRCodeScanner())
            .frame(width: 320, height: 240)
    }
#endif

// MARK: - Test Info

// @test-file: Tests/ViewModels/PushPairingViewModelTests.swift
