//
//  RetentionPruner.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// A folder the pruner may delete from.
struct RetentionRoot: Sendable {
    let url: URL
    /// When set, only file names with this prefix are candidates.
    let namePrefix: String?
    /// True for the incident folder, the only root where a record's files are removed by stem.
    let holdsRecordFiles: Bool

    static func incidentFolder(_ url: URL) -> RetentionRoot {
        RetentionRoot(url: url, namePrefix: nil, holdsRecordFiles: true)
    }

    static func captureCopies(_ url: URL, namePrefix: String) -> RetentionRoot {
        RetentionRoot(url: url, namePrefix: namePrefix, holdsRecordFiles: false)
    }
}

/// A file older than `maxAge` is deleted; files created before `startDate` age from `startDate`.
struct RetentionPolicy: Sendable, Equatable {
    let maxAge: TimeInterval
    let startDate: Date
}

struct RetentionReport: Sendable, Equatable {
    var deleted = 0
    var kept = 0
    var failed = 0
}

protocol RetentionPruning: Sendable {
    /// Throws `CancellationError` when a newer sweep replaces this one.
    func prune(policy: RetentionPolicy, now: Date) async throws -> RetentionReport

    /// Deletes the incident-folder files named `<stem>.<extension>`.
    func removeRecordFiles(stem: String) async -> RetentionReport

    func hasFiles(createdBefore date: Date) async -> Bool
}

/// Deletes only regular, non-hidden files at the top level of fixed roots; never recurses or follows symlinks.
actor RetentionPruner: RetentionPruning {
    private struct Candidate {
        let name: String
        let createdAt: Date?
        let isPartialRecording: Bool
    }

    /// CameraSnap stages each recording as a hidden file in the destination folder, and a crash leaves it behind; a finished recording takes seconds, so one this old is an orphan.
    static let partialRecordingMaxAge: TimeInterval = 24 * 60 * 60

    private let configuredRoots: [RetentionRoot]

    private let allowedBase: URL

    private let forbiddenRoots: @Sendable () -> [URL]

    private let logger: LogProtocol

    /// Resolved inside the actor because looking up the ubiquity container can block.
    private lazy var roots: [RetentionRoot] = allowedRoots()

    /// Every root must resolve inside `allowedBase` (the app's home, which is the container when sandboxed).
    init(roots: [RetentionRoot],
         allowedBase: URL = FileManager.default.homeDirectoryForCurrentUser,
         forbiddenRoots: @escaping @Sendable () -> [URL],
         logger: LogProtocol = Log(category: .retention))
    {
        configuredRoots = roots
        self.allowedBase = allowedBase
        self.forbiddenRoots = forbiddenRoots
        self.logger = logger
    }

    /// The incident folder, CameraSnap's save-to-disk folder, and the legacy PhotoSnap folder (user-approved exception to the no-legacy rule); iCloud stays forbidden.
    static func live(incidentDirectory: URL?, cameraSnapCopies: RetentionRoot) -> RetentionPruner {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var roots = [cameraSnapCopies, .captureCopies(home.appendingPathComponent("PhotoSnap"), namePrefix: "snapshot_")]
        if let incidentDirectory {
            roots.insert(.incidentFolder(incidentDirectory), at: 0)
        }
        return RetentionPruner(roots: roots, allowedBase: home) {
            [FileManager.default.url(forUbiquityContainerIdentifier: nil)].compactMap(\.self)
        }
    }

    func prune(policy: RetentionPolicy, now: Date) throws -> RetentionReport {
        var report = RetentionReport()
        for root in roots {
            try withOpenRoot(root) { fd, candidates in
                for candidate in candidates {
                    try Task.checkCancellation()
                    guard let createdAt = candidate.createdAt else {
                        logger.info("Kept a file with no creation or modification date")
                        report.kept += 1
                        continue
                    }
                    let isExpired = candidate.isPartialRecording
                        ? now.timeIntervalSince(createdAt) > Self.partialRecordingMaxAge
                        : now.timeIntervalSince(max(createdAt, policy.startDate)) > policy.maxAge
                    if isExpired {
                        remove(candidate.name, in: fd, into: &report)
                    } else {
                        report.kept += 1
                    }
                }
            }
        }
        return report
    }

    func removeRecordFiles(stem: String) -> RetentionReport {
        var report = RetentionReport()
        guard !stem.isEmpty, !stem.hasPrefix("."), !stem.contains("/") else {
            logger.error("Refused to remove record files for an invalid name")
            return report
        }
        for root in roots where root.holdsRecordFiles {
            withOpenRoot(root) { fd, candidates in
                for candidate in candidates where !candidate.isPartialRecording && (candidate.name as NSString).deletingPathExtension == stem {
                    remove(candidate.name, in: fd, into: &report)
                }
            }
        }
        return report
    }

    func hasFiles(createdBefore date: Date) -> Bool {
        var found = false
        for root in roots where !found {
            withOpenRoot(root) { _, candidates in
                found = candidates.contains { !$0.isPartialRecording && ($0.createdAt ?? .distantFuture) < date }
            }
        }
        return found
    }

    // MARK: - private

    private func allowedRoots() -> [RetentionRoot] {
        let base = Self.resolvedPath(of: allowedBase)
        let forbidden = forbiddenRoots().map(Self.resolvedPath(of:))
        return configuredRoots.filter { root in
            let path = Self.resolvedPath(of: root.url)
            guard path.hasPrefix(base + "/") else {
                logger.error("Refused a retention root outside the app's home folder")
                return false
            }
            guard !forbidden.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) else {
                logger.error("Refused a retention root inside a protected folder")
                return false
            }
            return true
        }
    }

    /// Opens the root itself with O_NOFOLLOW, so a root swapped for a symlink is refused; every later check and delete is relative to this descriptor.
    private func withOpenRoot(_ root: RetentionRoot, _ body: (Int32, [Candidate]) throws -> Void) rethrows {
        let path = root.url.standardizedFileURL.path
        var info = stat()
        guard lstat(path, &info) == 0 else { return }
        guard info.st_mode & S_IFMT == S_IFDIR else {
            logger.error("Refused a retention root that is not a plain folder")
            return
        }
        let fd = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { return }
        defer { close(fd) }
        try body(fd, candidates(in: root, path: path, fd: fd))
    }

    private func candidates(in root: RetentionRoot, path: String, fd: Int32) -> [Candidate] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [] }
        return names.compactMap { name in
            let isPartial = root.holdsRecordFiles && Self.isPartialRecordingName(name)
            guard isPartial || (!name.hasPrefix(".") && (root.namePrefix.map(name.hasPrefix) ?? true)) else { return nil }
            var info = stat()
            guard fstatat(fd, name, &info, AT_SYMLINK_NOFOLLOW) == 0, info.st_mode & S_IFMT == S_IFREG else { return nil }
            return Candidate(name: name, createdAt: Self.creationDate(of: info), isPartialRecording: isPartial)
        }
    }

    /// `unlinkat` never recurses and removes a symlink itself, never its target, even if a file was swapped after the check.
    private func remove(_ name: String, in fd: Int32, into report: inout RetentionReport) {
        if unlinkat(fd, name, 0) == 0 || errno == ENOENT {
            report.deleted += 1
        } else {
            logger.error("Could not delete an expired capture")
            report.failed += 1
        }
    }

    /// Exactly `.camerasnap-<UUID>.mov`, the staging name CameraSnap 0.3.1 uses.
    private static func isPartialRecordingName(_ name: String) -> Bool {
        let prefix = ".camerasnap-"
        let suffix = ".mov"
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return false }
        let middle = name.dropFirst(prefix.count).dropLast(suffix.count)
        return middle.count == 36 && UUID(uuidString: String(middle)) != nil
    }

    private static func creationDate(of info: stat) -> Date? {
        let time = info.st_birthtimespec.tv_sec != 0 ? info.st_birthtimespec : info.st_mtimespec
        guard time.tv_sec != 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / 1_000_000_000)
    }

    private static func resolvedPath(of url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
