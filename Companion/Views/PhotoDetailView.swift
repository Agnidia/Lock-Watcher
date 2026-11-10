//
//  PhotoDetailView.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// Read-only by design: the Mac owns the files, so there is no share, edit or delete action.
struct PhotoDetailView: View {
    let photo: CloudPhoto
    let library: CloudPhotoLibrary

    @State private var state: CloudPhotoImageState = .loading

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(Text(photo.date, format: .dateTime.day().month().year().hour().minute()))
            .navigationBarTitleDisplayMode(.inline)
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
            Image(cgImage, scale: 1, label: Text("PhotoAccessibilityLabel"))
                .resizable()
                .scaledToFit()
                .accessibilityValue(Text(photo.date, format: .dateTime.day().month().year().hour().minute()))
        case .failed:
            ContentUnavailableView("PhotoLoadFailedTitle", systemImage: "exclamationmark.triangle", description: Text("PhotoLoadFailedMessage"))
        }
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CloudPhotoLibraryTests.swift
