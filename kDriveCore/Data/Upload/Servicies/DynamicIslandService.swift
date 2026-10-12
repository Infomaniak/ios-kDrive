/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import BackgroundTasks
@preconcurrency import Combine
import Foundation
import InfomaniakCore
import InfomaniakDI
import kDriveResources
import OSLog
#if DEBUG
import UserNotifications
#endif

@available(iOS 26.0, *)
public class DynamicIslandService: DynamicIslandServiceable {
    @LazyInjectService private var uploadProgressTracker: DynamicIslandUploadProgressTracker
    @LazyInjectService private var uploadService: UploadServiceable
    @LazyInjectService private var photoLibraryUploader: PhotoLibraryUploadable
    @LazyInjectService private var taskScheduler: BGTaskScheduler

    private let taskIdentifier = "com.infomaniak.drive.background-upload-dynamic-island"
    private static let logger = Logger(category: "DynamicIslandService")

    @MainActor private var currentTask: BGContinuedProcessingTask?
    @MainActor private var uploadContinuationBox: DynamicIslandTaskCompletion?

    @MainActor public var isProtectingUploads: Bool {
        guard currentTask != nil, let uploadContinuationBox else { return false }
        return uploadContinuationBox.result == nil
    }

    @MainActor private var taskHandlingTask: Task<Void, Never>?
    private var hasRegisteredLaunchHandler = false
    private let registrationQueue = DispatchQueue(label: "com.infomaniak.drive.dynamic-island-service.registration")

    private enum DomainError: Error {
        case expiredTask
        #if DEBUG
        case taskAlreadyRunning
        #endif
    }

    public func registerTask() {
        registrationQueue.sync {
            guard !hasRegisteredLaunchHandler else { return }

            taskScheduler.register(forTaskWithIdentifier: taskIdentifier, using: nil) { [weak self] task in
                guard let self, let task = task as? BGContinuedProcessingTask else { return }
                DispatchQueue.main.async {
                    self.handle(task: task)
                }
            }

            hasRegisteredLaunchHandler = true
        }
    }

    public func submitTask() {
        DispatchQueue.main.async {
            self.submitTaskOnMain()
        }
    }

    @MainActor private func submitTaskOnMain() {
        guard currentTask == nil else {
            Self.logger.info("Task already in progress, skipping submit")
            return
        }

        let request = BGContinuedProcessingTaskRequest(
            identifier: taskIdentifier,
            title: KDriveResourcesStrings.Localizable.uploadingTitle,
            subtitle: KDriveResourcesStrings.Localizable.dynamicIslandPreparationTitle
        )
        request.strategy = .queue

        do {
            try taskScheduler.submit(request)
            Self.logger.info("Dynamic Island task submitted")
        } catch {
            Self.logger.error("Error submitting task : \(error)")
            #if DEBUG
            reportFailure(stage: "Submission", error: error)
            #endif
        }
    }

    public func cancelTaskError(_ error: Error) {
        Self.logger.error("Uploading error in task: \(error)")

        DispatchQueue.main.async {
            self.uploadContinuationBox?.complete(with: .failure(error))
        }
    }

    @MainActor private func handleExpiration(completion: DynamicIslandTaskCompletion) {
        guard uploadContinuationBox === completion, completion.result == nil else { return }
        Self.logger.error("Handling task expiration")
        #if DEBUG
        reportFailure(stage: "Expiration handler (iOS does not provide the expiration reason)", error: DomainError.expiredTask)
        #endif
        uploadService.suspendAllOperations()
        completion.complete(with: .failure(DomainError.expiredTask))
    }

    public func updateQueueActivity(globalQueueActive: Bool, photoQueueActive: Bool) {
        DispatchQueue.main.async {
            self.uploadProgressTracker.updateQueueActivity(
                globalQueueActive: globalQueueActive,
                photoQueueActive: photoQueueActive
            )

            if globalQueueActive || photoQueueActive {
                self.submitTaskOnMain()
            }
        }
    }

    @MainActor private func handle(task: BGContinuedProcessingTask) {
        guard currentTask == nil else {
            #if DEBUG
            reportFailure(stage: "Launch rejected: another task is running", error: DomainError.taskAlreadyRunning)
            #endif
            task.setTaskCompleted(success: false)
            return
        }
        let completion = DynamicIslandTaskCompletion()
        uploadContinuationBox = completion
        currentTask = task

        task.expirationHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.handleExpiration(completion: completion)
            }
        }

        taskHandlingTask = Task { @MainActor in
            await run(task: task, completion: completion)
        }
    }

    @MainActor private func run(task: BGContinuedProcessingTask, completion: DynamicIslandTaskCompletion) async {
        let (observation, refreshTask) = startProgressReporting(task: task, completion: completion)
        defer {
            refreshTask.cancel()
            observation.cancel()
            cleanUp(task: task, completion: completion)
        }

        do {
            try await waitForUploads(completion: completion)
            refreshTask.cancel()
            completeSuccessfully(task: task)
        } catch {
            refreshTask.cancel()
            await completeWithError(task: task, error: error)
        }
    }

    @MainActor private func startProgressReporting(
        task: BGContinuedProcessingTask,
        completion: DynamicIslandTaskCompletion
    ) -> (AnyCancellable, Task<Void, Never>) {
        var lastDisplayedPercentage: Int?
        let refreshProgress: @MainActor (Double) -> Void = { progress in
            guard completion.result == nil else { return }
            self.updateProgress(task: task, fractionCompleted: progress, lastDisplayedPercentage: &lastDisplayedPercentage)
        }
        let observation = uploadProgressTracker.$fractionCompleted.sink { progress in
            refreshProgress(progress)
        }
        let refreshTask = Task { @MainActor in
            await refreshProgressPeriodically(completion: completion, refreshProgress: refreshProgress)
        }
        return (observation, refreshTask)
    }

    @MainActor private func updateProgress(
        task: BGContinuedProcessingTask,
        fractionCompleted: Double,
        lastDisplayedPercentage: inout Int?
    ) {
        let fraction = min(max(fractionCompleted, 0), 1)
        task.progress.totalUnitCount = Int64(max(uploadProgressTracker.totalUploadCount, 1)) * 1_000_000
        task.progress.completedUnitCount = Int64(fraction * Double(task.progress.totalUnitCount))

        let percentage = Int(fraction * 100)
        guard percentage != lastDisplayedPercentage else { return }
        lastDisplayedPercentage = percentage
        task.updateTitle(
            KDriveResourcesStrings.Localizable.uploadInProgressTitle,
            subtitle: KDriveResourcesStrings.Localizable.uploadInProgressSubTitle(percentage)
        )
    }

    @MainActor private func refreshProgressPeriodically(
        completion: DynamicIslandTaskCompletion,
        refreshProgress: @MainActor (Double) -> Void
    ) async {
        // Refresh independently of Realm notifications without inventing upload progress.
        while !Task.isCancelled && completion.result == nil {
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            refreshProgress(uploadProgressTracker.fractionCompleted)
        }
    }

    @MainActor private func waitForUploads(completion: DynamicIslandTaskCompletion) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            completion.install(continuation)
            guard completion.result == nil else { return }

            uploadService.waitForCompletionForActiveQueues {
                DispatchQueue.main.async {
                    completion.complete(with: .success(()))
                }
            }
        }
    }

    @MainActor private func completeSuccessfully(task: BGContinuedProcessingTask) {
        let totalCount = uploadProgressTracker.totalUploadCount
        let uploadedCount = min(uploadProgressTracker.progressUploading + 1, totalCount)
        let status = ReachabilityListener.instance.currentStatus

        if uploadService.operationCount > 0 && status != .wifi && photoLibraryUploader.isWifiOnly {
            task.updateTitle(
                KDriveResourcesStrings.Localizable.uploadNetworkErrorWifiRequired,
                subtitle: KDriveResourcesStrings.Localizable.dynamicIslandUploadSuccessful(uploadedCount, totalCount)
            )
        } else {
            task.updateTitle(
                KDriveResourcesStrings.Localizable.allUploadFinishedTitle,
                subtitle: uploadedCount > 1 ?
                    KDriveResourcesStrings.Localizable.allUploadFinishedDescriptionPlural(uploadedCount)
                    : KDriveResourcesStrings.Localizable
                    .allUploadFinishedDescription(KDriveResourcesStrings.Localizable.fileDetailsInfoFile(1))
            )
        }
        task.setTaskCompleted(success: true)
    }

    @MainActor private func completeWithError(task: BGContinuedProcessingTask, error: Error) async {
        #if DEBUG
        if (error as? DomainError) != .expiredTask {
            reportFailure(stage: "Upload task", error: error)
        }
        #endif
        let (title, subtitle) = errorInfo(for: error)
        task.updateTitle(title, subtitle: subtitle)

        try? await Task.sleep(for: .seconds(5))
        task.setTaskCompleted(success: (error as? DomainError) == .expiredTask)
    }

    @MainActor private func cleanUp(task: BGContinuedProcessingTask, completion: DynamicIslandTaskCompletion) {
        let isExpiredTask: Bool
        if case .failure(let error) = completion.result {
            isExpiredTask = (error as? DomainError) == .expiredTask
        } else {
            isExpiredTask = false
        }
        if !isExpiredTask {
            uploadProgressTracker.reset()
        }
        currentTask = nil
        uploadContinuationBox = nil
        task.expirationHandler = nil
        taskHandlingTask = nil
    }

    #if DEBUG
    @MainActor private func reportFailure(stage: String, error: Error) {
        let details = failureDetails(stage: stage, error: error)
        Self.logger.error("\(details, privacy: .public)")
        sendFailureNotification(details: details)
    }

    @MainActor private func failureDetails(stage: String, error: Error) -> String {
        let nsError = error as NSError
        var details = """
        DynamicIslandService: \(stage)
        Error: \(String(reflecting: error))
        NSError: domain=\(nsError.domain), code=\(nsError.code), description=\(nsError.localizedDescription)
        userInfo: \(String(reflecting: nsError.userInfo))
        """
        if let driveError = error as? DriveError {
            details += "\nDriveError: type=\(driveError.type), code=\(driveError.code)"
            if let underlyingError = driveError.underlyingError {
                let underlyingNSError = underlyingError as NSError
                details += """

                Underlying error: \(String(reflecting: underlyingError))
                domain=\(underlyingNSError.domain), code=\(underlyingNSError.code)
                userInfo: \(String(reflecting: underlyingNSError.userInfo))
                """
            }
        }
        details += """

        Operations: total=\(uploadService.operationCount), suspended=\(uploadService.isSuspended)
        Progress: \(currentTask?.progress.completedUnitCount ?? 0)/\(currentTask?.progress.totalUnitCount ?? 0)
        Uploads: completed=\(uploadProgressTracker.progressUploading), total=\(uploadProgressTracker.totalUploadCount)
        Network: \(ReachabilityListener.instance.currentStatus)
        """
        return details
    }

    private func sendFailureNotification(details: String) {
        let content = UNMutableNotificationContent()
        content.title = KDriveResourcesStrings.Localizable.errorUpload
        content.subtitle = "DynamicIslandService"
        content.body = details
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "\(taskIdentifier).diagnostic.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.logger.error("Unable to deliver Dynamic Island diagnostic: \(String(reflecting: error), privacy: .public)")
            }
        }
    }
    #endif

    private func errorInfo(for error: Error) -> (String, String) {
        if let driveError = error as? DriveError {
            switch driveError {
            case .quotaExceeded:
                return (
                    KDriveResourcesStrings.Localizable.exceedQuotaTitle,
                    KDriveResourcesStrings.Localizable.errorQuotaExceeded
                )
            case .productMaintenance, .driveMaintenance:
                return (
                    KDriveResourcesStrings.Localizable.maintenanceTitle,
                    KDriveResourcesStrings.Localizable.tryAgainLater
                )
            default:
                break
            }
        }

        if error is FreeSpaceService.StorageIssues {
            return (
                KDriveResourcesStrings.Localizable.insufficientSpaceTitle,
                KDriveResourcesStrings.Localizable.insufficientSpaceDescription
            )
        }

        return (
            KDriveResourcesStrings.Localizable.errorTitle,
            KDriveResourcesStrings.Localizable.openAppToContinue
        )
    }
}

public class UnavailableDynamicIslandService: DynamicIslandServiceable {
    @MainActor public var isProtectingUploads: Bool { false }

    public func registerTask() {}

    public func submitTask() {}

    public func cancelTaskError(_ error: Error) {}

    public func updateQueueActivity(globalQueueActive: Bool, photoQueueActive: Bool) {}
}
