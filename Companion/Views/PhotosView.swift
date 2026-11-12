//
//  PhotosView.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

struct PhotosView: View {
    let library: CloudPhotoLibrary
    let isPro: Bool
    let showPro: () -> Void
    @Binding var path: NavigationPath

    private static let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                content
            }
            .refreshable { await library.refresh() }
            .navigationTitle("TabPhotos")
            .navigationDestination(for: CloudPhoto.self) { photo in
                PhotoDetailView(photo: photo, library: library, isPro: isPro, showPro: showPro)
            }
        }
    }

    /// Every state sits inside the ScrollView so pull-to-refresh also works on the empty, unavailable and failed screens.
    @ViewBuilder
    private var content: some View {
        switch library.phase {
        case .loading:
            ProgressView("PhotosLoading")
                .containerRelativeFrame([.horizontal, .vertical])
        case .unavailable:
            ContentUnavailableView("PhotosUnavailableTitle", systemImage: "icloud.slash", description: Text("PhotosUnavailableMessage"))
                .containerRelativeFrame([.horizontal, .vertical])
        case .failed:
            ContentUnavailableView {
                Label("PhotosFailedTitle", systemImage: "exclamationmark.icloud")
            } description: {
                Text("PhotosFailedMessage")
            } actions: {
                Button("PhotosRetry") {
                    Task { await library.refresh() }
                }
            }
            .containerRelativeFrame([.horizontal, .vertical])
        case .empty:
            ContentUnavailableView("PhotosEmptyTitle", systemImage: "photo.on.rectangle", description: Text("PhotosEmptyMessage"))
                .containerRelativeFrame([.horizontal, .vertical])
        case .loaded(let photos):
            LazyVGrid(columns: Self.columns, spacing: 2) {
                ForEach(photos) { photo in
                    NavigationLink(value: photo) {
                        PhotoThumbnail(photo: photo, library: library)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct PhotoThumbnail: View {
    let photo: CloudPhoto
    let library: CloudPhotoLibrary

    @State private var state: CloudPhotoImageState = .loading

    var body: some View {
        Color.secondary.opacity(0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay { image }
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("PhotoAccessibilityLabel")
            .accessibilityValue(Text(photo.date, format: .dateTime.day().month().year().hour().minute()))
            .task(id: photo.id) {
                let result = await library.image(for: photo, maxPixelSize: 360)
                if !Task.isCancelled {
                    state = result
                }
            }
    }

    @ViewBuilder
    private var image: some View {
        switch state {
        case .loading:
            ProgressView()
        case .loaded(let cgImage):
            Image(decorative: cgImage, scale: 1)
                .resizable()
                .scaledToFill()
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
    #Preview("Grid") {
        let library = PreviewModels.photos()
        PhotosView(library: library, isPro: true, showPro: {}, path: .constant(NavigationPath()))
            .task { await library.refresh() }
    }

    #Preview("Empty") {
        let library = PreviewModels.photos(mode: .empty)
        PhotosView(library: library, isPro: true, showPro: {}, path: .constant(NavigationPath()))
            .task { await library.refresh() }
    }

    #Preview("Unavailable") {
        let library = PreviewModels.photos(mode: .unavailable)
        PhotosView(library: library, isPro: true, showPro: {}, path: .constant(NavigationPath()))
            .task { await library.refresh() }
    }

    #Preview("Thumbnail") {
        PhotoThumbnail(photo: FixturePhotoSource.photos()[0], library: PreviewModels.photos())
            .frame(width: 120)
    }
#endif

// MARK: - Test Info

// @test-file: CompanionTests/CloudPhotoLibraryTests.swift
