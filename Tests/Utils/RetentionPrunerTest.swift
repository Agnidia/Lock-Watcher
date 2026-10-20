//
//  RetentionPrunerTest.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest
@testable import Lock_Watcher

final class RetentionPrunerTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var sandbox: URL!
    private var incident: URL!
    private var copies: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = FileManager.default.temporaryDirectory.appendingPathComponent("RetentionPrunerTests-\(UUID().uuidString)", isDirectory: true)
        incident = sandbox.appendingPathComponent("Lock-Watcher", isDirectory: true)
        copies = sandbox.appendingPathComponent("CameraSnap", isDirectory: true)
        for folder in [incident!, copies!] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
        try super.tearDownWithError()
    }

    @discardableResult
    private func makeFile(_ name: String, in folder: URL, ageDays: Double) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        let date = now.addingTimeInterval(-ageDays * day)
        try FileManager.default.setAttributes([.creationDate: date, .modificationDate: date], ofItemAtPath: url.path)
        return url
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func makePruner(forbidden: [URL] = [], allowedBase: URL? = nil, roots: [RetentionRoot]? = nil) -> RetentionPruner {
        RetentionPruner(roots: roots ?? [.incidentFolder(incident), .captureCopies(copies, namePrefix: "snapshot_")],
                        allowedBase: allowedBase ?? FileManager.default.homeDirectoryForCurrentUser,
                        forbiddenRoots: { forbidden },
                        logger: LogMock())
    }

    // MARK: - Periods

    func testEachPeriodDeletesOnlyOlderFiles() async throws {
        let expectations: [(RetentionPeriod, Set<Int>)] = [(.oneWeek, [8, 32, 366]), (.oneMonth, [32, 366]), (.oneYear, [366])]
        for (period, deletedAges) in expectations {
            try? FileManager.default.removeItem(at: incident)
            try FileManager.default.createDirectory(at: incident, withIntermediateDirectories: true)
            var files = [Int: URL]()
            for age in [6, 8, 32, 366] {
                files[age] = try makeFile("capture-\(age).jpeg", in: incident, ageDays: Double(age))
            }

            let policy = RetentionPolicy(maxAge: period.maxAge, startDate: now.addingTimeInterval(-400 * day))
            let report = try await makePruner().prune(policy: policy, now: now)

            for (age, url) in files {
                XCTAssertEqual(exists(url), !deletedAges.contains(age), "\(period) age \(age)")
            }
            XCTAssertEqual(report.deleted, deletedAges.count, "\(period)")
        }
    }

    func testAfterUploadFallsBackToOneWeek() async throws {
        let recent = try makeFile("recent.mov", in: incident, ageDays: 6)
        let stale = try makeFile("stale.mov", in: incident, ageDays: 8)

        let policy = RetentionPolicy(maxAge: RetentionPeriod.afterUpload.maxAge, startDate: now.addingTimeInterval(-400 * day))
        _ = try await makePruner().prune(policy: policy, now: now)

        XCTAssertTrue(exists(recent))
        XCTAssertFalse(exists(stale))
    }

    func testPreUpgradeFileAgesFromStartDate() async throws {
        let upgrade = now
        let old = try makeFile("old.jpeg", in: incident, ageDays: 30)
        let policy = RetentionPolicy(maxAge: RetentionPeriod.oneWeek.maxAge, startDate: upgrade)
        let pruner = makePruner()

        _ = try await pruner.prune(policy: policy, now: upgrade.addingTimeInterval(7 * day))
        XCTAssertTrue(exists(old))

        _ = try await pruner.prune(policy: policy, now: upgrade.addingTimeInterval(8 * day))
        XCTAssertFalse(exists(old))
    }

    // MARK: - Scope

    func testFilesOutsideTheRootsSurvive() async throws {
        let sibling = sandbox.appendingPathComponent("Sibling", isDirectory: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        let siblingFile = try makeFile("capture.jpeg", in: sibling, ageDays: 400)
        let nested = incident.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let nestedFile = try makeFile("capture.jpeg", in: nested, ageDays: 400)
        let hidden = try makeFile(".hidden.jpeg", in: incident, ageDays: 400)
        let unprefixed = try makeFile("other.png", in: copies, ageDays: 400)
        let prefixed = try makeFile("snapshot_1.png", in: copies, ageDays: 400)

        let policy = RetentionPolicy(maxAge: RetentionPeriod.oneWeek.maxAge, startDate: now.addingTimeInterval(-400 * day))
        _ = try await makePruner().prune(policy: policy, now: now)

        XCTAssertTrue(exists(siblingFile))
        XCTAssertTrue(exists(nestedFile))
        XCTAssertTrue(exists(nested))
        XCTAssertTrue(exists(hidden))
        XCTAssertTrue(exists(unprefixed))
        XCTAssertFalse(exists(prefixed))
    }

    func testSymlinksAreNeitherFollowedNorDeleted() async throws {
        let outside = sandbox.appendingPathComponent("Outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let target = try makeFile("target.jpeg", in: outside, ageDays: 400)
        let link = incident.appendingPathComponent("link.jpeg")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let policy = RetentionPolicy(maxAge: RetentionPeriod.oneWeek.maxAge, startDate: now.addingTimeInterval(-400 * day))
        _ = try await makePruner().prune(policy: policy, now: now)

        XCTAssertTrue(exists(target))
        XCTAssertNotNil(try? FileManager.default.destinationOfSymbolicLink(atPath: link.path))
    }

    func testRootInsideForbiddenFolderIsRefused() async throws {
        let old = try makeFile("old.jpeg", in: incident, ageDays: 400)

        let policy = RetentionPolicy(maxAge: RetentionPeriod.oneWeek.maxAge, startDate: now.addingTimeInterval(-400 * day))
        let report = try await makePruner(forbidden: [sandbox]).prune(policy: policy, now: now)

        XCTAssertTrue(exists(old))
        XCTAssertEqual(report, RetentionReport())
    }

    func testSymlinkedRootIsRefused() async throws {
        let real = sandbox.appendingPathComponent("Real", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let old = try makeFile("old.jpeg", in: real, ageDays: 400)
        let link = sandbox.appendingPathComponent("Linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        let policy = RetentionPolicy(maxAge: RetentionPeriod.oneWeek.maxAge, startDate: now.addingTimeInterval(-400 * day))
        let report = try await makePruner(roots: [.incidentFolder(link)]).prune(policy: policy, now: now)

        XCTAssertTrue(exists(old))
        XCTAssertEqual(report.deleted, 0)
    }

    func testRootOutsideAllowedBaseIsRefused() async throws {
        let old = try makeFile("old.jpeg", in: incident, ageDays: 400)

        let policy = RetentionPolicy(maxAge: RetentionPeriod.oneWeek.maxAge, startDate: now.addingTimeInterval(-400 * day))
        _ = try await makePruner(allowedBase: copies).prune(policy: policy, now: now)

        XCTAssertTrue(exists(old))
    }

    func testStalePartialRecordingIsPrunedAfterOneDay() async throws {
        let stale = try makeFile(".camerasnap-\(UUID().uuidString).mov", in: incident, ageDays: 2)
        let fresh = try makeFile(".camerasnap-\(UUID().uuidString).mov", in: incident, ageDays: 0.5)
        let lookalike = try makeFile(".camerasnap-notauuid.mov", in: incident, ageDays: 2)
        let inCopies = try makeFile(".camerasnap-\(UUID().uuidString).mov", in: copies, ageDays: 2)
        let record = try makeFile("capture.jpeg", in: incident, ageDays: 2)

        let policy = RetentionPolicy(maxAge: RetentionPeriod.oneYear.maxAge, startDate: now.addingTimeInterval(-400 * day))
        _ = try await makePruner().prune(policy: policy, now: now)

        XCTAssertFalse(exists(stale))
        XCTAssertTrue(exists(fresh))
        XCTAssertTrue(exists(lookalike))
        XCTAssertTrue(exists(inCopies))
        XCTAssertTrue(exists(record))
    }

    func testMissingRootIsIgnored() async throws {
        try FileManager.default.removeItem(at: incident)

        let policy = RetentionPolicy(maxAge: RetentionPeriod.oneWeek.maxAge, startDate: now)
        let report = try await makePruner().prune(policy: policy, now: now)

        XCTAssertEqual(report.deleted, 0)
    }

    // MARK: - Record files

    func testRemoveRecordFilesDeletesOnlyThatStemInIncidentFolder() async throws {
        let movie = try makeFile("2026-10-06_10-00-00.000.mov", in: incident, ageDays: 0)
        let poster = try makeFile("2026-10-06_10-00-00.000.jpeg", in: incident, ageDays: 0)
        let otherRecord = try makeFile("2026-10-06_11-00-00.000.jpeg", in: incident, ageDays: 0)
        let copy = try makeFile("snapshot_2026-10-06_10-00-00.000.png", in: copies, ageDays: 0)

        let report = await makePruner().removeRecordFiles(stem: "2026-10-06_10-00-00.000")

        XCTAssertEqual(report.deleted, 2)
        XCTAssertFalse(exists(movie))
        XCTAssertFalse(exists(poster))
        XCTAssertTrue(exists(otherRecord))
        XCTAssertTrue(exists(copy))
    }

    func testRemoveRecordFilesRefusesUnsafeStem() async throws {
        let file = try makeFile("x.jpeg", in: incident, ageDays: 0)

        for stem in ["", "../x", ".hidden"] {
            let report = await makePruner().removeRecordFiles(stem: stem)
            XCTAssertEqual(report.deleted, 0, stem)
        }
        XCTAssertTrue(exists(file))
    }

    func testHasFilesCreatedBefore() async throws {
        try makeFile("old.jpeg", in: incident, ageDays: 10)
        let pruner = makePruner()

        let hasOlderThanFiveDays = await pruner.hasFiles(createdBefore: now.addingTimeInterval(-5 * day))
        let hasOlderThanTwentyDays = await pruner.hasFiles(createdBefore: now.addingTimeInterval(-20 * day))

        XCTAssertTrue(hasOlderThanFiveDays)
        XCTAssertFalse(hasOlderThanTwentyDays)
    }
}

// MARK: - Source Info

// @source-file: Source/Utils/RetentionPruner.swift
