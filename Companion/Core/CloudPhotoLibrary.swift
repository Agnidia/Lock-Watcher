//
//  CloudPhotoLibrary.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreGraphics
import Foundation
import Observation

/// A file the Mac app uploaded; `id` is the file name, unique inside the flat `Documents` folder.
struct CloudPhoto: Sendable, Hashable, Identifiable {
    let id: String
    let url: URL
    let date: Date
    /// The size the iCloud listing reports before any download; nil when the listing carries none.
    let byteSize: Int?

    init(url: URL, date: Date, byteSize: Int? = nil) {
        id = url.lastPathComponent
        self.url = url
        self.date = date
        self.byteSize = byteSize
    }
}

enum CloudPhotoError: Error, Sendable, Equatable {
    /// No iCloud account, iCloud Drive off for this app, or no ubiquity container.
    case unavailable
    case unreadable
}

/// Read-only window onto the Mac's upload folder. `listPhotos` returns every file; the library decides what is a still.
protocol CloudPhotoSource: Sendable {
    func listPhotos() async throws -> [CloudPhoto]
    func imageData(for photo: CloudPhoto) async throws -> Data
}

enum CloudPhotoCatalog {
    static let stillExtensions = CloudCaptureContract.stillExtensions
    /// Far above any snapshot the Mac uploads. A larger file is refused before it is downloaded, possibly over cellular, or read.
    static let maxFileBytes = 50 * 1024 * 1024

    /// An unknown size passes here because the read checks the size on disk again.
    static func isWithinSizeCap(_ byteSize: Int?) -> Bool {
        byteSize.map { (0 ... maxFileBytes).contains($0) } ?? true
    }

    /// Dot files cover iCloud placeholders (`.name.icloud`); videos and unknown types are dropped because only stills are decoded.
    static func stills(from candidates: [CloudPhoto]) -> [CloudPhoto] {
        var seen = Set<String>()
        return candidates
            .filter {
                !$0.id.hasPrefix(".") && stillExtensions.contains($0.url.pathExtension.lowercased()) && isWithinSizeCap($0.byteSize)
                    && seen.insert($0.id).inserted
            }
            .sorted { ($0.date, $0.id) > ($1.date, $1.id) }
    }
}

enum CloudPhotoImageState: Sendable {
    case loading
    case loaded(CGImage)
    case failed
}

/// The single owner of the photo list: load state for the grid and cached, size-bounded decoding for the cells.
@MainActor
@Observable
final class CloudPhotoLibrary {
    enum Phase: Equatable, Sendable {
        case loading
        case unavailable
        case failed
        case empty
        case loaded([CloudPhoto])
    }

    /// A count limit alone lets a few 2048 px detail bitmaps (about 16 MB each) pile up; this bounds the bytes held.
    static let imageCacheCostLimit = 64 * 1024 * 1024

    private(set) var phase: Phase = .loading

    @ObservationIgnored private let source: any CloudPhotoSource
    @ObservationIgnored private let imageCache = NSCache<NSString, CGImage>()
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    init(source: any CloudPhotoSource) {
        self.source = source
        imageCache.countLimit = 120
        imageCache.totalCostLimit = Self.imageCacheCostLimit
    }

    static func cacheCost(of image: CGImage) -> Int {
        image.bytesPerRow * image.height
    }

    /// Overlapping callers (activation, pull-to-refresh) share one pass, which runs unstructured so a cancelled `.refreshable` cannot abort it half way.
    func refresh() async {
        if let inFlight {
            await inFlight.value
            return
        }
        let task = Task { await load() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    func image(for photo: CloudPhoto, maxPixelSize: Int) async -> CloudPhotoImageState {
        let key = "\(photo.id)|\(photo.date.timeIntervalSince1970)|\(maxPixelSize)" as NSString
        if let cached = imageCache.object(forKey: key) {
            return .loaded(cached)
        }
        guard let data = try? await source.imageData(for: photo),
              let image = await CloudPhotoImageDecoder.decode(data, maxPixelSize: maxPixelSize) else { return .failed }
        imageCache.setObject(image, forKey: key, cost: Self.cacheCost(of: image))
        return .loaded(image)
    }

    private func load() async {
        do {
            let photos = try await CloudPhotoCatalog.stills(from: source.listPhotos())
            phase = photos.isEmpty ? .empty : .loaded(photos)
        } catch CloudPhotoError.unavailable {
            phase = .unavailable
        } catch {
            // A failed refresh must not blank a list the user is already looking at.
            if case .loaded = phase {
                return
            }
            phase = .failed
        }
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CloudPhotoLibraryTests.swift
