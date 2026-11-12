//
//  ICloudPhotoSource.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Reads the Mac's upload folder (`Documents` of the default ubiquity container). It never writes, renames, moves or deletes there.
struct ICloudPhotoSource: CloudPhotoSource {
    private static let gatherTimeout = Duration.seconds(20)
    private static let downloadTimeout = Duration.seconds(30)

    func listPhotos() async throws -> [CloudPhoto] {
        guard FileManager.default.ubiquityIdentityToken != nil, await Self.hasContainer() else { throw CloudPhotoError.unavailable }
        return try await MetadataGatherer().gather(timeout: Self.gatherTimeout)
    }

    @concurrent
    func imageData(for photo: CloudPhoto) async throws -> Data {
        guard photo.url.isFileURL, CloudPhotoCatalog.stillExtensions.contains(photo.url.pathExtension.lowercased()),
              CloudPhotoCatalog.isWithinSizeCap(photo.byteSize) else { throw CloudPhotoError.unreadable }
        try await Self.waitUntilDownloaded(photo.url)
        return try Self.coordinatedRead(photo.url)
    }

    /// The first container lookup can block on iCloud, and Apple asks for it off the main thread before a metadata query starts.
    @concurrent
    private static func hasContainer() async -> Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }

    /// A coordinated read of a not-yet-downloaded item blocks with no way out, so the download is requested and polled with a deadline instead.
    @concurrent
    private static func waitUntilDownloaded(_ url: URL) async throws {
        guard isPlaceholder(url) else { return }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        let deadline = ContinuousClock.now.advanced(by: downloadTimeout)
        while isPlaceholder(url) {
            guard ContinuousClock.now < deadline else { throw CloudPhotoError.unreadable }
            try await Task.sleep(for: .milliseconds(400))
        }
    }

    private static func isPlaceholder(_ url: URL) -> Bool {
        var fresh = url
        fresh.removeAllCachedResourceValues()
        return (try? fresh.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus == .notDownloaded
    }

    private static func coordinatedRead(_ url: URL) throws -> Data {
        var coordinationError: NSError?
        var outcome: Result<Data, any Error> = .failure(CloudPhotoError.unreadable)
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { readableURL in
            outcome = Result { try readCapped(readableURL, maxBytes: CloudPhotoCatalog.maxFileBytes) }
        }
        if coordinationError != nil {
            throw CloudPhotoError.unreadable
        }
        return try outcome.get()
    }

    /// The listing size can be stale or absent, so the size on disk is checked again. A mapped read lets ImageIO touch only the pages it parses.
    static func readCapped(_ url: URL, maxBytes: Int) throws -> Data {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, (0 ... maxBytes).contains(size) else {
            throw CloudPhotoError.unreadable
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }
}

/// A metadata query sees items that are not downloaded yet under their real names, unlike a directory listing that shows `.name.icloud` stubs.
@MainActor
private final class MetadataGatherer {
    private let query = NSMetadataQuery()
    private var observer: (any NSObjectProtocol)?
    private var timeoutTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<[CloudPhoto], any Error>?

    func gather(timeout: Duration) async throws -> [CloudPhoto] {
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.finish(timedOut: false) }
            }
            // The query must start on a run-loop thread; the deadline keeps a stalled iCloud daemon from leaving the grid loading forever.
            query.start()
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.finish(timedOut: true)
            }
        }
    }

    private func finish(timedOut: Bool) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        query.disableUpdates()
        query.stop()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        if timedOut {
            continuation.resume(throwing: CloudPhotoError.unreadable)
        } else {
            continuation.resume(returning: query.results.compactMap { ($0 as? NSMetadataItem).flatMap(Self.photo(from:)) })
        }
    }

    private static func photo(from item: NSMetadataItem) -> CloudPhoto? {
        guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { return nil }
        let date = (item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date)
            ?? (item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date)
            ?? .distantPast
        let byteSize = (item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.intValue
        return CloudPhoto(url: url, date: date, byteSize: byteSize)
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CloudPhotoLibraryTests.swift
