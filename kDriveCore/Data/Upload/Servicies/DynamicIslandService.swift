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

    @MainActor private var taskHandlingTask: Task<Void, Never>?
    private var hasRegisteredLaunchHandler = false
    private let registrationQueue = DispatchQueue(label: "com.infomaniak.drive.dynamic-island-service.registration")

    private enum DomainError: Error {
        case expiredTask
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
            var cancellable: AnyCancellable?
            defer {
                cancellable?.cancel()
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
                    completion.install(continuation)
                    guard completion.result == nil else { return }

                    uploadService.waitForCompletionForActiveQueues {
                        DispatchQueue.main.async {
                            completion.complete(with: .success(()))
                        }
                    }
                }

                let totalCount = uploadProgressTracker.totalUploadCount
                let uploadedCount = min(uploadProgressTracker.progressUploading + 1, totalCount)

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
        }
    }

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
    public func registerTask() {}

    public func submitTask() {}

    public func cancelTaskError(_ error: Error) {}

    public func updateQueueActivity(globalQueueActive: Bool, photoQueueActive: Bool) {}
}
