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

@preconcurrency import BackgroundTasks
@preconcurrency import Combine
import Foundation
import InfomaniakCore
import InfomaniakDI
import kDriveResources
import OSLog

@available(iOS 26.0, *)
public actor DynamicIslandService: DynamicIslandServiceable {
    @LazyInjectService private var uploadProgressTracker: DynamicIslandUploadProgressTracker
    @LazyInjectService private var uploadService: UploadServiceable
    @LazyInjectService private var photoLibraryUploader: PhotoLibraryUploadable
    @LazyInjectService private var taskScheduler: BGTaskScheduler

    private let taskIdentifier = "com.infomaniak.drive.background-upload-dynamic-island"

    private static let logger = Logger(category: "DynamicIslandService")

    private var currentTask: BGContinuedProcessingTask?
    private var uploadContinuation: CheckedContinuation<Void, any Error>?
    private var lastError: Error?

    private var taskHandlingTask: Task<Void, Never>?
    private var hasRegisteredLaunchHandler = false

    private enum DomainError: Error {
        case expiredTask
    }

    public func registerTask() {
        guard !hasRegisteredLaunchHandler else { return }

        taskScheduler.register(forTaskWithIdentifier: taskIdentifier, using: nil) { [weak self] task in
            guard let self, let task = task as? BGContinuedProcessingTask else { return }
            Task { await self.handle(task: task) }
        }

        hasRegisteredLaunchHandler = true
    }

    public func submitTask() {
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
        }
    }

    public func cancelTaskError(_ error: Error) {
        Self.logger.error("Uploading error in task: \(error)")

        lastError = error
        resumeUploadContinuation(throwing: error)
    }

    private func handleExpiration() {
        Self.logger.error("Handling task expiration")
        uploadService.suspendAllOperations()
        resumeUploadContinuation(throwing: DomainError.expiredTask)
    }

    public func updateQueueActivity(globalQueueActive: Bool, photoQueueActive: Bool) {
        uploadProgressTracker.updateQueueActivity(
            globalQueueActive: globalQueueActive,
            photoQueueActive: photoQueueActive
        )

        if globalQueueActive || photoQueueActive {
            submitTask()
        }
    }

    private func handle(task: BGContinuedProcessingTask) {
        lastError = nil
        currentTask = task

        task.expirationHandler = { [weak self] in
            guard let self else { return }
            Task { await self.handleExpiration() }
        }

        taskHandlingTask = Task { [weak self] in
            await self?.runTask(task)
        }
    }

    private func runTask(_ task: BGContinuedProcessingTask) async {
        var cancellable: AnyCancellable?
        defer {
            cancellable?.cancel()
            currentTask = nil
            uploadContinuation = nil
            lastError = nil
        }

        task.progress.totalUnitCount = 100

        cancellable = uploadProgressTracker.$fractionCompleted.sink { progress in
            task.progress.completedUnitCount = Int64(progress * 100)
            task.updateTitle(
                KDriveResourcesStrings.Localizable.uploadInProgressTitle,
                subtitle: KDriveResourcesStrings.Localizable.uploadInProgressSubTitle(Int(progress * 100))
            )
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                uploadContinuation = continuation

                uploadService.waitForCompletionForActiveQueues { [weak self] in
                    Task { await self?.resumeUploadContinuation() }
                }
            }

            let progressSnapshot = await uploadProgressTracker.progressSnapshot()
            let totalCount = progressSnapshot.totalUploadCount
            let uploadedCount = min(progressSnapshot.progressUploading + 1, totalCount)

            let status = ReachabilityListener.instance.currentStatus
            let shouldBeSuspended = status != .wifi
            let wifiSynchro = photoLibraryUploader.isWifiOnly

            if uploadService.operationCount > 0 && shouldBeSuspended && wifiSynchro {
                task.updateTitle(
                    KDriveResourcesStrings.Localizable.uploadNetworkErrorWifiRequired,
                    subtitle: KDriveResourcesStrings.Localizable.dynamicIslandUploadSuccessful(
                        uploadedCount,
                        totalCount
                    )
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
        } catch {
            let (title, subtitle) = errorInfo(for: error)
            task.updateTitle(title, subtitle: subtitle)

            try? await Task.sleep(for: .seconds(5))

            if let domainError = error as? DomainError, domainError == .expiredTask {
                task.setTaskCompleted(success: true)
            } else {
                task.setTaskCompleted(success: false)
            }
        }

        cancellable?.cancel()
        cancellable = nil

        let isExpiredTask = (lastError as? DomainError) == .expiredTask
        if !isExpiredTask {
            await uploadProgressTracker.reset()
        }
    }

    private func resumeUploadContinuation() {
        guard let continuation = uploadContinuation else {
            return
        }
        uploadContinuation = nil
        continuation.resume()
    }

    private func resumeUploadContinuation(throwing error: Error) {
        guard let continuation = uploadContinuation else {
            return
        }
        uploadContinuation = nil
        continuation.resume(throwing: error)
    }

    private nonisolated func errorInfo(for error: Error) -> (String, String) {
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

public final class UnavailableDynamicIslandService: DynamicIslandServiceable {
    public func registerTask() async {}

    public func submitTask() async {}

    public func cancelTaskError(_ error: Error) async {}

    public func updateQueueActivity(globalQueueActive: Bool, photoQueueActive: Bool) async {}
}
