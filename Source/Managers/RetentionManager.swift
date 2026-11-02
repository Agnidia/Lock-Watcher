//
//  RetentionManager.swift
//
//  Created on 06.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

protocol DateProviding: Sendable {
    var now: Date { get }
}

struct SystemDateProvider: DateProviding {
    var now: Date {
        Date()
    }
}

/// True when the app process is only hosting unit tests; such a launch must not touch user files or show UI.
enum LaunchEnvironment {
    /// Always false in release builds, so an environment variable can never switch retention off in a shipped app.
    static var isHostingTests: Bool {
        #if DEBUG
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #else
            false
        #endif
    }
}

/// Runs the "Keep files" rule at launch, after each incident, and when the setting changes.
@MainActor
protocol RetentionManaging: AnyObject {
    func applicationDidLaunch() async
    func incidentRecorded(_ thiefDto: ThiefDto, report: DeliveryReport) async
    func retentionSettingChanged() async
}

@MainActor
final class RetentionManager: RetentionManaging {
    private var settings: AppSettingsProtocol

    private let pruner: any RetentionPruning

    private let dateProvider: any DateProviding

    private let noticePresenter: any RetentionNoticePresenting

    private let logger: LogProtocol

    private var sweepTask: Task<Void, Never>?

    init(settings: AppSettingsProtocol,
         pruner: any RetentionPruning,
         dateProvider: any DateProviding = SystemDateProvider(),
         noticePresenter: any RetentionNoticePresenting,
         logger: LogProtocol = Log(category: .retention))
    {
        self.settings = settings
        self.pruner = pruner
        self.dateProvider = dateProvider
        self.noticePresenter = noticePresenter
        self.logger = logger
    }

    func applicationDidLaunch() async {
        let startDate = ensureStartDate()
        if !settings.retention.isUpgradeNoticeShown {
            // Marked before presenting, so a crash or force quit during the notice cannot show it again.
            settings.retention.isUpgradeNoticeShown = true
            if await pruner.hasFiles(createdBefore: startDate) {
                let period = settings.retention.keepFiles
                await noticePresenter.presentUpgradeNotice(period: period, firstDeletion: startDate.addingTimeInterval(period.maxAge))
            }
        }
        await sweep()
    }

    func incidentRecorded(_ thiefDto: ThiefDto, report: DeliveryReport) async {
        if settings.retention.keepFiles == .afterUpload, report.isRemoteUploadConfirmed,
           let stem = (thiefDto.videoURL ?? thiefDto.filePath)?.deletingPathExtension().lastPathComponent
        {
            let result = await pruner.removeRecordFiles(stem: stem)
            logger.info("Removed \(result.deleted) local file(s) of an uploaded record")
        }
        await sweep()
    }

    func retentionSettingChanged() async {
        await sweep()
    }

    // MARK: - private

    private func ensureStartDate() -> Date {
        if let startDate = settings.retention.startDate {
            return startDate
        }
        let now = dateProvider.now
        settings.retention.startDate = now
        return now
    }

    /// A newer sweep cancels the running one, so only the latest policy deletes files.
    private func sweep() async {
        sweepTask?.cancel()
        let policy = RetentionPolicy(maxAge: settings.retention.keepFiles.maxAge, startDate: ensureStartDate())
        let now = dateProvider.now
        let pruner = pruner
        let logger = logger
        let task = Task {
            do {
                let report = try await pruner.prune(policy: policy, now: now)
                logger.info("Retention sweep: \(report.deleted) deleted, \(report.kept) kept, \(report.failed) failed")
            } catch {
                logger.debug("Retention sweep superseded")
            }
        }
        sweepTask = task
        await task.value
    }
}

/// Used when the app only hosts unit tests: no sweep, no notice.
@MainActor
final class DisabledRetentionManager: RetentionManaging {
    func applicationDidLaunch() async {}

    func incidentRecorded(_ thiefDto: ThiefDto, report: DeliveryReport) async {}

    func retentionSettingChanged() async {}
}
