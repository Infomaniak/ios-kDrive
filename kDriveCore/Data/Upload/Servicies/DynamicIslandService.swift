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
import InfomaniakDI
import kDriveResources
import OSLog

@available(iOS 26.0, *)
public actor DynamicIslandService {
    public static let shared = DynamicIslandService()

    @LazyInjectService private var dynamicIslandManager: DynamicIslandManager
    @LazyInjectService private var uploadService: UploadServiceable

    private let taskIdentifier: String

    private static let logger = Logger(category: "DynamicIslandService")

    private var currentTask: BGContinuedProcessingTask?
    private var uploadContinuationBox: ContinuationBox?
    private var lastError: Error?

    private enum DomainError: Error {
        case expiredTask
    }

    private init() {
        taskIdentifier = "com.infomaniak.drive.background-upload-dynamic-island"
    }

    public func registerTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { [weak self] task in
            guard let self, let task = task as? BGContinuedProcessingTask else { return }
            Task { await self.handle(task: task) }
        }

        dynamicIslandManager.setup()
    }

    public func submitTask() {
        // Avoid creating multiple tasks
        guard currentTask == nil else {
            Self.logger.info("Task already in progress, skipping submit")
            return
        }

        // TODO: Strings are hard-coded, use string resources with Loco
        let request = BGContinuedProcessingTaskRequest(
            identifier: taskIdentifier,
            title: "Uploading",
            subtitle: "Preparation..."
        )
        request.strategy = .fail

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
        lastError = DomainError.expiredTask
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
            Task {
                await self.handleExpiration()
            }
        }

        Task {
            var cancellable: AnyCancellable?
            defer {
                cancellable?.cancel()
                let isExpiredTask = (lastError as? DomainError) == .expiredTask
                if !isExpiredTask {
                    dynamicIslandManager.reset()
                }
                currentTask = nil
                uploadContinuationBox = nil
                lastError = nil
            }
            task.progress.totalUnitCount = 100

            // TODO: Check the value of progress
            cancellable = dynamicIslandManager.$fractionCompleted.sink { progress in
                task.progress.completedUnitCount = Int64(progress * 100)
                task.updateTitle(
                    KDriveResourcesStrings.Localizable.uploadInProgressTitle,
                    subtitle: "Progress \(progress.formatted(.defaultPercent))"
                )
            }

            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    let box = ContinuationBox(continuation)
                    self.uploadContinuationBox = box

                    dynamicIslandManager.uploadService.waitForCompletion {
                        box.resume()
                    }
                }

                // TODO: Add gestion when uploadCount == 1 file
                let uploadCount = dynamicIslandManager.getTotalUploadCount()
                task.updateTitle(
                    KDriveResourcesStrings.Localizable.allUploadFinishedTitle,
                    subtitle: KDriveResourcesStrings.Localizable.allUploadFinishedDescriptionPlural(uploadCount)
                )

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
        if let domainError = error as? DomainError {
            switch domainError {
            case .expiredTask:
                return ("Importation en pause", "Ouvrez l'app pour reprendre")
            }
        }

        if let driveError = error as? DriveError {
            switch driveError {
            case .quotaExceeded:
                return ("Quota dépassé", "Espace kDrive insuffisant")
            case .productMaintenance, .driveMaintenance:
                return ("Maintenance", "Réessayez plus tard")
            default:
                break
            }
        }

        if error is FreeSpaceService.StorageIssues {
            return ("Espace insuffisant", "Libérez de l'espace")
        }

        return ("Erreur", "Ouvrez l'app pour continuer")
    }
}

public extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Percent {
    static var defaultPercent: FloatingPointFormatStyle<Double>.Percent {
        return .percent.precision(.fractionLength(0))
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
