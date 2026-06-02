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

@available(iOS 26.0, *)
public struct DynamicIslandService {
    public static let shared = DynamicIslandService()

    @LazyInjectService private var dynamicIslandManager: DynamicIslandManager
    @LazyInjectService private var uploadService: UploadServiceable

    private enum DomainError: Error {
        case expiredTask
    }

    private let taskIdentifier: String

    private init() {
        taskIdentifier = "com.infomaniak.drive.background-upload-dynamic-island.\(UUID().uuidString)"
    }

    public func registerTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let task = task as? BGContinuedProcessingTask else { return }
            self.handle(task: task)
        }

        dynamicIslandManager.setup()
    }

    public func submitTask() {
        // TODO: Strings are hard-coded, use string resources with Loco
        let request = BGContinuedProcessingTaskRequest(
            identifier: taskIdentifier,
            title: "Uploading",
            subtitle: "Preparation..."
        )
        request.strategy = .fail

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Dynamic Island task submitted")
        } catch {
            print("Error submitting task : \(error)")
        }
    }

    private func handle(task: BGContinuedProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            var cancellable: AnyCancellable?
            task.progress.totalUnitCount = 100

            // TODO: Check the value of progress
            cancellable = dynamicIslandManager.$fractionCompleted.sink { progress in
                task.progress.completedUnitCount = Int64(progress * 100)
                task.updateTitle(
                    KDriveResourcesStrings.Localizable.uploadInProgressTitle,
                    subtitle: "Progress \(progress.formatted(.defaultPercent))"
                )
            }

            await withCheckedContinuation { uploadContinuation in
                dynamicIslandManager.uploadService.waitForCompletion {
                    uploadContinuation.resume()
                }
            }

            // TODO: Add gestion when uploadCount == 1 file
            let uploadCount = dynamicIslandManager.getTotalUploadCount()
            task.updateTitle(
                KDriveResourcesStrings.Localizable.allUploadFinishedTitle,
                subtitle: KDriveResourcesStrings.Localizable.allUploadFinishedDescriptionPlural(uploadCount)
            )

            task.setTaskCompleted(success: true)
            cancellable?.cancel()
            dynamicIslandManager.reset()
        }
    }
}

public extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Percent {
    static var defaultPercent: FloatingPointFormatStyle<Double>.Percent {
        return .percent.precision(.fractionLength(0))
    }
}
