/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import CocoaLumberjackSwift
import Foundation
import InfomaniakDI
import kDriveCore

extension AppDelegate {
    /* To debug background tasks:
      Launch ->
      e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.infomaniak.background.refresh"]
     OR
      e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.infomaniak.background.long-refresh"]

      Force early termination ->
      e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.infomaniak.background.refresh"]
     OR
      e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.infomaniak.background.long-refresh"]
     */

    /// schedule background tasks
    func scheduleBackgroundRefresh() {
        BGTaskSchedulingLog("scheduleBackgroundRefresh")
        // List pictures + upload files (+pictures) / photoKit
        let backgroundRefreshRequest = BGAppRefreshTaskRequest(identifier: Constants.backgroundRefreshIdentifier)
        #if DEBUG
        // Required for debugging
        backgroundRefreshRequest.earliestBeginDate = Date()
        #else
        backgroundRefreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        #endif

        // Upload files (+pictures) / photokit
        let longBackgroundRefreshRequest = BGProcessingTaskRequest(identifier: Constants.longBackgroundRefreshIdentifier)
        #if DEBUG
        // Required for debugging
        longBackgroundRefreshRequest.earliestBeginDate = Date()
        #else
        longBackgroundRefreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        #endif
        longBackgroundRefreshRequest.requiresNetworkConnectivity = true
        longBackgroundRefreshRequest.requiresExternalPower = true
        do {
            try backgroundTaskScheduler.submit(backgroundRefreshRequest)
            BGTaskSchedulingLog("scheduled task: \(backgroundRefreshRequest)")
            try backgroundTaskScheduler.submit(longBackgroundRefreshRequest)
            BGTaskSchedulingLog("scheduled task: \(longBackgroundRefreshRequest)")

        } catch {
            BGTaskSchedulingLog("Error scheduling background task: \(error)", level: .error)
        }
    }

    /// Register BackgroundTasks in scheduler for later
    func registerBackgroundTasks() {
        BGTaskSchedulingLog("registerBackgroundTasks")
        var registered = backgroundTaskScheduler.register(forTaskWithIdentifier: Constants.backgroundRefreshIdentifier, using: nil) { task in
            self.scheduleBackgroundRefresh()
            @InjectService var uploadQueue: UploadQueue
            task.expirationHandler = {
                BGTaskSchedulingLog("Task \(Constants.backgroundRefreshIdentifier) EXPIRED", level: .error)
                uploadQueue.suspendAllOperations()
                uploadQueue.cancelRunningOperations()
                task.setTaskCompleted(success: false)
            }

            self.handleBackgroundRefresh { _ in
                BGTaskSchedulingLog("Task \(Constants.backgroundRefreshIdentifier) completed with SUCCESS")
                task.setTaskCompleted(success: true)
            }
        }
        BGTaskSchedulingLog("Task \(Constants.backgroundRefreshIdentifier) registered ? \(registered)")

        registered = backgroundTaskScheduler.register(forTaskWithIdentifier: Constants.longBackgroundRefreshIdentifier, using: nil) { task in
            self.scheduleBackgroundRefresh()
            @InjectService var uploadQueue: UploadQueue
            task.expirationHandler = {
                BGTaskSchedulingLog("Task \(Constants.longBackgroundRefreshIdentifier) EXPIRED", level: .error)
                uploadQueue.suspendAllOperations()
                uploadQueue.cancelRunningOperations()
                task.setTaskCompleted(success: false)
            }

            self.handleBackgroundRefresh { _ in
                BGTaskSchedulingLog("Task \(Constants.longBackgroundRefreshIdentifier) completed with SUCCESS")
                task.setTaskCompleted(success: true)
            }
        }
        BGTaskSchedulingLog("Task \(Constants.longBackgroundRefreshIdentifier) registered ? \(registered)")
    }

    func handleBackgroundRefresh(completion: @escaping (Bool) -> Void) {
        BGTaskSchedulingLog("handleBackgroundRefresh")
        // User installed the app but never logged in
        @InjectService var accountManager: AccountManageable
        if accountManager.accounts.isEmpty {
            completion(false)
            return
        }

        BGTaskSchedulingLog("Enqueue new pictures")
        @InjectService var photoUploader: PhotoLibraryUploader
        photoUploader.scheduleNewPicturesForUpload()

        BGTaskSchedulingLog("Clean errors for all uploads")
        @InjectService var uploadQueue: UploadQueue
        uploadQueue.cleanNetworkAndLocalErrorsForAllOperations()

        BGTaskSchedulingLog("Reload operations in queue")
        uploadQueue.rebuildUploadQueueFromObjectsInRealm()

        BGTaskSchedulingLog("waitForCompletion")
        uploadQueue.waitForCompletion {
            completion(true)
        }
    }
}
