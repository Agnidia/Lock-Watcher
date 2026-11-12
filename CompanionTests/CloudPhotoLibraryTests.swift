//
//  CloudPhotoLibraryTests.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest

private func photo(_ name: String, at seconds: TimeInterval) -> CloudPhoto {
    CloudPhoto(url: URL(filePath: "/icloud/Documents/\(name)"), date: Date(timeIntervalSince1970: seconds))
}

private func renderedImage(width: CGFloat = 400, height: CGFloat = 300) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { context in
        UIColor.systemTeal.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

private func gifData() throws -> Data {
    let data = NSMutableData()
    let cgImage = try XCTUnwrap(renderedImage(width: 40, height: 40).cgImage)
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, cgImage, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
}

actor StubCloudPhotoSource: CloudPhotoSource {
    private var listing: Result<[CloudPhoto], CloudPhotoError>
    private var images: [String: Data]
    private(set) var listRequests = 0
    private(set) var imageRequests = 0

    init(listing: Result<[CloudPhoto], CloudPhotoError>, images: [String: Data] = [:]) {
        self.listing = listing
        self.images = images
    }

    func setListing(_ listing: Result<[CloudPhoto], CloudPhotoError>) {
        self.listing = listing
    }

    func listPhotos() async throws -> [CloudPhoto] {
        listRequests += 1
        return try listing.get()
    }

    func imageData(for photo: CloudPhoto) async throws -> Data {
        imageRequests += 1
        guard let data = images[photo.id] else { throw CloudPhotoError.unreadable }
        return data
    }
}

final class CloudPhotoCatalogTests: XCTestCase {
    func testKeepsStillsAndDropsVideosHiddenAndOthers() {
        let candidates = [
            photo("a.jpeg", at: 1), photo("b.JPG", at: 2), photo("c.png", at: 3), photo("d.heic", at: 4),
            photo("clip.mov", at: 5), photo(".hidden.jpeg", at: 6), photo(".stub.jpeg.icloud", at: 7),
            photo("notes.txt", at: 8), photo("noextension", at: 9)
        ]

        let ids = CloudPhotoCatalog.stills(from: candidates).map(\.id)

        XCTAssertEqual(Set(ids), ["a.jpeg", "b.JPG", "c.png", "d.heic"])
    }

    func testNewestFirstWithStableTieBreak() {
        let candidates = [photo("old.jpeg", at: 10), photo("b.jpeg", at: 30), photo("a.jpeg", at: 30), photo("mid.jpeg", at: 20)]

        XCTAssertEqual(CloudPhotoCatalog.stills(from: candidates).map(\.id), ["b.jpeg", "a.jpeg", "mid.jpeg", "old.jpeg"])
    }

    func testDuplicateNamesCollapseToOne() {
        let candidates = [photo("a.jpeg", at: 1), photo("a.jpeg", at: 1)]

        XCTAssertEqual(CloudPhotoCatalog.stills(from: candidates).count, 1)
    }

    func testListedSizeAboveTheCapIsDroppedBeforeDownload() {
        let cap = CloudPhotoCatalog.maxFileBytes
        let candidates = [("at-cap.jpeg", cap), ("over.jpeg", cap + 1), ("negative.jpeg", -1), ("unknown.jpeg", nil)].map { name, size in
            CloudPhoto(url: URL(filePath: "/icloud/Documents/\(name)"), date: .distantPast, byteSize: size)
        }

        XCTAssertEqual(Set(CloudPhotoCatalog.stills(from: candidates).map(\.id)), ["at-cap.jpeg", "unknown.jpeg"])
    }
}

final class ICloudPhotoSourceReadTests: XCTestCase {
    private func temporaryFile(bytes: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).jpeg")
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        return url
    }

    func testReadRefusesFilesOverTheCapOnDisk() throws {
        let url = try temporaryFile(bytes: 2048)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try ICloudPhotoSource.readCapped(url, maxBytes: 2047)) { XCTAssertEqual($0 as? CloudPhotoError, .unreadable) }
        XCTAssertEqual(try ICloudPhotoSource.readCapped(url, maxBytes: 2048), Data(repeating: 0xAB, count: 2048))
    }

    func testListedSizeAboveTheCapIsRefusedEvenWhenTheFileIsSmall() async throws {
        let url = try temporaryFile(bytes: 16)
        defer { try? FileManager.default.removeItem(at: url) }

        let unknown = try await ICloudPhotoSource().imageData(for: CloudPhoto(url: url, date: .distantPast))
        XCTAssertEqual(unknown.count, 16)
        do {
            _ = try await ICloudPhotoSource().imageData(for: CloudPhoto(url: url, date: .distantPast, byteSize: CloudPhotoCatalog.maxFileBytes + 1))
            XCTFail("expected the listed size to be refused")
        } catch {
            XCTAssertEqual(error as? CloudPhotoError, .unreadable)
        }
    }
}

@MainActor
final class CloudPhotoLibraryTests: XCTestCase {
    func testLoadingThenLoadedNewestFirst() async {
        let source = StubCloudPhotoSource(listing: .success([photo("a.jpeg", at: 10), photo("clip.mov", at: 50), photo("b.jpeg", at: 20)]))
        let sut = CloudPhotoLibrary(source: source)
        XCTAssertEqual(sut.phase, .loading)

        await sut.refresh()

        XCTAssertEqual(sut.phase, .loaded([photo("b.jpeg", at: 20), photo("a.jpeg", at: 10)]))
    }

    func testEmptyWhenNoStills() async {
        let sut = CloudPhotoLibrary(source: StubCloudPhotoSource(listing: .success([photo("clip.mov", at: 1), photo(".x.jpeg", at: 2)])))

        await sut.refresh()

        XCTAssertEqual(sut.phase, .empty)
    }

    func testUnavailableWithoutICloud() async {
        let sut = CloudPhotoLibrary(source: StubCloudPhotoSource(listing: .failure(.unavailable)))

        await sut.refresh()

        XCTAssertEqual(sut.phase, .unavailable)
    }

    func testRefreshPicksUpNewPhotoAndSignOut() async {
        let source = StubCloudPhotoSource(listing: .success([]))
        let sut = CloudPhotoLibrary(source: source)
        await sut.refresh()
        XCTAssertEqual(sut.phase, .empty)

        await source.setListing(.success([photo("new.jpeg", at: 5)]))
        await sut.refresh()
        XCTAssertEqual(sut.phase, .loaded([photo("new.jpeg", at: 5)]))

        await source.setListing(.failure(.unavailable))
        await sut.refresh()
        XCTAssertEqual(sut.phase, .unavailable)
    }

    func testListingFailureKeepsLoadedListButFailsFreshLibrary() async {
        let source = StubCloudPhotoSource(listing: .failure(.unreadable))
        let sut = CloudPhotoLibrary(source: source)

        await sut.refresh()
        XCTAssertEqual(sut.phase, .failed)

        await source.setListing(.success([photo("a.jpeg", at: 1)]))
        await sut.refresh()
        await source.setListing(.failure(.unreadable))
        await sut.refresh()
        XCTAssertEqual(sut.phase, .loaded([photo("a.jpeg", at: 1)]))
    }

    func testOverlappingRefreshesShareOnePass() async {
        let source = StubCloudPhotoSource(listing: .success([photo("a.jpeg", at: 1)]))
        let sut = CloudPhotoLibrary(source: source)

        async let first: Void = sut.refresh()
        async let second: Void = sut.refresh()
        _ = await (first, second)

        let requests = await source.listRequests
        XCTAssertEqual(requests, 1)
    }

    func testImageDecodesBoundedAndIsCached() async throws {
        let item = photo("a.jpeg", at: 1)
        let source = try StubCloudPhotoSource(listing: .success([item]), images: ["a.jpeg": XCTUnwrap(renderedImage().jpegData(compressionQuality: 0.8))])
        let sut = CloudPhotoLibrary(source: source)

        let first = await sut.image(for: item, maxPixelSize: 100)
        let second = await sut.image(for: item, maxPixelSize: 100)

        guard case .loaded(let image) = first, case .loaded = second else { return XCTFail("expected loaded, got \(first) and \(second)") }
        XCTAssertEqual(max(image.width, image.height), 100)
        let requests = await source.imageRequests
        XCTAssertEqual(requests, 1)
    }

    func testUnreadableAndCorruptImagesSurfaceAsFailed() async {
        let missing = photo("missing.jpeg", at: 1)
        let corrupt = photo("corrupt.jpeg", at: 2)
        let source = StubCloudPhotoSource(listing: .success([missing, corrupt]), images: ["corrupt.jpeg": Data("not an image".utf8)])
        let sut = CloudPhotoLibrary(source: source)

        let missingState = await sut.image(for: missing, maxPixelSize: 100)
        let corruptState = await sut.image(for: corrupt, maxPixelSize: 100)

        guard case .failed = missingState, case .failed = corruptState else { return XCTFail("expected failed, got \(missingState) and \(corruptState)") }
    }

    func testCacheCostIsTheBitmapSizeAndTheLimitHoldsSeveralDetailImages() throws {
        let image = try XCTUnwrap(renderedImage(width: 40, height: 30).cgImage)

        XCTAssertGreaterThanOrEqual(CloudPhotoLibrary.cacheCost(of: image), image.width * image.height * 4)
        XCTAssertGreaterThanOrEqual(CloudPhotoLibrary.imageCacheCostLimit, 3 * 2048 * 2048 * 4)
    }
}

final class CloudPhotoImageDecoderTests: XCTestCase {
    func testDownsamplesJPEGAndPNGKeepingAspectRatio() async throws {
        let jpeg = try await CloudPhotoImageDecoder.decode(XCTUnwrap(renderedImage().jpegData(compressionQuality: 0.8)), maxPixelSize: 100)
        let png = try await CloudPhotoImageDecoder.decode(XCTUnwrap(renderedImage().pngData()), maxPixelSize: 200)

        XCTAssertEqual(jpeg.map { [$0.width, $0.height] }, [100, 75])
        XCTAssertEqual(png.map { [$0.width, $0.height] }, [200, 150])
    }

    func testRejectsGarbageOtherFormatsAndBadSizes() async throws {
        let valid = try XCTUnwrap(renderedImage().jpegData(compressionQuality: 0.8))

        let garbage = await CloudPhotoImageDecoder.decode(Data("not an image".utf8), maxPixelSize: 100)
        let empty = await CloudPhotoImageDecoder.decode(Data(), maxPixelSize: 100)
        let gif = try await CloudPhotoImageDecoder.decode(gifData(), maxPixelSize: 100)
        let zeroSize = await CloudPhotoImageDecoder.decode(valid, maxPixelSize: 0)
        let truncated = await CloudPhotoImageDecoder.decode(valid.prefix(12), maxPixelSize: 100)

        XCTAssertNil(garbage)
        XCTAssertNil(empty)
        XCTAssertNil(gif)
        XCTAssertNil(zeroSize)
        XCTAssertNil(truncated)
    }

    func testRefusesSourcesAboveThePixelLimit() async throws {
        let image = renderedImage(width: 40, height: 30)
        let pixels = try XCTUnwrap(image.cgImage).width * XCTUnwrap(image.cgImage).height
        let png = try XCTUnwrap(image.pngData())

        let over = await CloudPhotoImageDecoder.decode(png, maxPixelSize: 100, sourcePixelLimit: pixels - 1)
        let at = await CloudPhotoImageDecoder.decode(png, maxPixelSize: 100, sourcePixelLimit: pixels)

        XCTAssertNil(over)
        XCTAssertNotNil(at)
        XCTAssertLessThanOrEqual(CloudPhotoImageDecoder.maxSourcePixels, 50_000_000)
    }

    func testProcessWideAllowlistIsAcceptedAndStillsStillDecode() async throws {
        XCTAssertTrue(CloudPhotoImageDecoder.restrictProcessWideTypes())
        XCTAssertTrue(CloudPhotoImageDecoder.restrictProcessWideTypes(), "a second call reports the first status")

        let jpeg = try await CloudPhotoImageDecoder.decode(XCTUnwrap(renderedImage().jpegData(compressionQuality: 0.8)), maxPixelSize: 100)
        let png = try await CloudPhotoImageDecoder.decode(XCTUnwrap(renderedImage().pngData()), maxPixelSize: 100)
        let gif = try await CloudPhotoImageDecoder.decode(gifData(), maxPixelSize: 100)

        XCTAssertNotNil(jpeg)
        XCTAssertNotNil(png)
        XCTAssertNil(gif)
    }
}

// MARK: - Source Info

// @source-file: Companion/Core/CloudPhotoLibrary.swift
// @doc-refs: Companion/Core/CloudPhotoImageDecoder.swift
