//
//  PhotoDetailView.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import UIKit

/// Never edits or deletes, because the Mac owns the files. Zoom and share are Pro; a free account sees the photo fitted and a locked share button.
struct PhotoDetailView: View {
    let photo: CloudPhoto
    let library: CloudPhotoLibrary
    let isPro: Bool
    let showPro: () -> Void

    @State private var state: CloudPhotoImageState = .loading

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(Text(photo.date, format: .dateTime.day().month().year().hour().minute()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    shareControl
                }
            }
            .task(id: photo.id) {
                let result = await library.image(for: photo, maxPixelSize: 2048)
                if !Task.isCancelled {
                    state = result
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("PhotosLoading")
        case .loaded(let cgImage):
            if isPro {
                ZoomableImage(image: cgImage)
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityValue(Text(photo.date, format: .dateTime.day().month().year().hour().minute()))
                    .accessibilityHint(Text("PhotoZoomHint"))
            } else {
                Image(cgImage, scale: 1, label: Text("PhotoAccessibilityLabel"))
                    .resizable()
                    .scaledToFit()
                    .accessibilityValue(Text(photo.date, format: .dateTime.day().month().year().hour().minute()))
            }
        case .failed:
            ContentUnavailableView("PhotoLoadFailedTitle", systemImage: "exclamationmark.triangle", description: Text("PhotoLoadFailedMessage"))
        }
    }

    /// The shared copy is the decoded, size-bounded image, so a huge original never lands in memory for a share.
    @ViewBuilder
    private var shareControl: some View {
        if case .loaded(let cgImage) = state {
            if isPro {
                let image = Image(decorative: cgImage, scale: 1)
                ShareLink(item: image, preview: SharePreview(Text("PhotoAccessibilityLabel"), image: image)) {
                    Label("AlertShare", systemImage: "square.and.arrow.up")
                }
            } else {
                Button(action: showPro) {
                    Label("AlertShare", systemImage: "lock")
                }
                .accessibilityHint(Text("PhotoProHint"))
            }
        }
    }
}

/// Pinch, pan and double-tap zoom. A `UIScrollView` gives the native feel (momentum, bounce) that a SwiftUI gesture stack does not.
private struct ZoomableImage: UIViewRepresentable {
    let image: CGImage

    func makeUIView(context: Context) -> ZoomScrollView {
        ZoomScrollView()
    }

    func updateUIView(_ view: ZoomScrollView, context: Context) {
        view.imageView.image = UIImage(cgImage: image)
        view.imageView.isAccessibilityElement = true
        view.imageView.accessibilityLabel = String(localized: "PhotoAccessibilityLabel")
    }
}

private final class ZoomScrollView: UIScrollView, UIScrollViewDelegate {
    static let maxZoom: CGFloat = 5
    static let doubleTapZoom: CGFloat = 3

    let imageView = UIImageView()

    init() {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = Self.maxZoom
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Resizes only at scale 1; while zoomed, the scroll view owns the frame.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard zoomScale == 1 else { return }
        imageView.frame = bounds
        contentSize = bounds.size
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    @objc
    private func toggleZoom(_ gesture: UITapGestureRecognizer) {
        guard zoomScale == 1 else {
            setZoomScale(1, animated: true)
            return
        }
        let point = gesture.location(in: imageView)
        let size = CGSize(width: bounds.width / Self.doubleTapZoom, height: bounds.height / Self.doubleTapZoom)
        zoom(to: CGRect(origin: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2), size: size), animated: true)
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CloudPhotoLibraryTests.swift
