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
public class DynamicIslandService: DynamicIslandServicable {
    @LazyInjectService private var dynamicIslandManager: DynamicIslandManager
    @LazyInjectService private var uploadService: UploadServiceable
    @LazyInjectService private var photoLibraryUploader: PhotoLibraryUploadable

    private let taskIdentifier: String

    private static let logger = Logger(category: "DynamicIslandService")

    private var currentTask: BGContinuedProcessingTask?
    private var uploadContinuationBox: ContinuationBox?
    private var lastError: Error?

    private var taskHandlingTask: Task<Void, Never>?
    private var hasRegisteredLaunchHandler = false
    private let registrationQueue = DispatchQueue(label: "com.infomaniak.drive.dynamic-island-service.registration")

    private enum DomainError: Error {
        case expiredTask
    }

    init() {
        taskIdentifier = "com.infomaniak.drive.background-upload-dynamic-island"
    }

    public func registerTask() {
        registrationQueue.sync {
            guard !hasRegisteredLaunchHandler else { return }

            BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { [weak self] task in
                guard let self, let task = task as? BGContinuedProcessingTask else { return }
                taskHandlingTask = Task { self.handle(task: task) }
            }

            hasRegisteredLaunchHandler = true
        }
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
            try BGTaskScheduler.shared.submit(request)
            Self.logger.info("Dynamic Island task submitted")
        } catch {
            Self.logger.error("Error submitting task : \(error)")
        }
    }

    public func cancelTaskError(_ error: Error) {
        Self.logger.error("Uploading error in task: \(error)")

        lastError = error
        uploadContinuationBox?.resume(throwing: error)
        uploadContinuationBox = nil
    }

    private func handleExpiration() {
        Self.logger.error("Handling task expiration")
        uploadService.suspendAllOperations()
        uploadContinuationBox?.resume(throwing: DomainError.expiredTask)
        uploadContinuationBox = nil
    }

    public func updateQueueActivity(globalQueueActive: Bool, photoQueueActive: Bool) {
        dynamicIslandManager.updateQueueActivity(
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
            self.handleExpiration()
        }

        Task {
            var cancellable: AnyCancellable?
            defer {
                cancellable?.cancel()
                let isExpiredTask = (self.lastError as? DomainError) == .expiredTask
                if !isExpiredTask {
                    dynamicIslandManager.reset()
                }
                currentTask = nil
                uploadContinuationBox = nil
                lastError = nil
            }
            task.progress.totalUnitCount = 100

            cancellable = dynamicIslandManager.$fractionCompleted.sink { progress in
                task.progress.completedUnitCount = Int64(progress * 100)
                task.updateTitle(
                    KDriveResourcesStrings.Localizable.uploadInProgressTitle,
                    subtitle: KDriveResourcesStrings.Localizable.uploadInProgressSubTitle(Int(progress * 100))
                )
            }

            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    let box = ContinuationBox(continuation)
                    self.uploadContinuationBox = box

                    dynamicIslandManager.uploadService.waitForCompletionForActiveQueues {
                        box.resume()
                    }
                }

                let totalCount = dynamicIslandManager.totalUploadCount
                let uploadedCount = min(dynamicIslandManager.progressUploading + 1, totalCount)

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

private final class ContinuationBox: @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, any Error>?

    init(_ continuation: CheckedContinuation<Void, any Error>) {
        self.continuation = continuation
    }

    func resume() {
        guard let c = continuation else { return }
        continuation = nil
        c.resume()
    }

    func resume(throwing error: Error) {
        guard let c = continuation else { return }
        continuation = nil
        c.resume(throwing: error)
    }
}

public class UnavailableDynamicIslandService: DynamicIslandServicable {
    public func registerTask() {}

    public func submitTask() {}

    public func cancelTaskError(_ error: Error) {}

    public func updateQueueActivity(globalQueueActive: Bool, photoQueueActive: Bool) {}
}
