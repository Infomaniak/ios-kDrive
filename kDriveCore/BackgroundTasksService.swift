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

/// Service to ask the system to do some work in the background later.
public protocol BackgroundTasksServiceable {
    /// Ask the system to handle the app's background refresh
    func registerBackgroundTasks()

    /// Schedule next refresh with the system
    func scheduleBackgroundRefresh()
}

struct BackgroundTasksService: BackgroundTasksServiceable {
    @LazyInjectService var scheduler: BGTaskScheduler

    public init() {
        // Sonar Cloud happy
    }

    public func registerBackgroundTasks() {
        Log.backgroundTaskScheduling("registerBackgroundTasks")
        registerBackgroundTask(identifier: Constants.backgroundRefreshIdentifier)
        registerBackgroundTask(identifier: Constants.longBackgroundRefreshIdentifier)
    }

    public func buildBackgroundTask(_ task: BGTask, identifier: String, scheduler: BGTaskScheduler) {
        scheduleBackgroundRefresh()

        handleBackgroundRefresh { _ in
            Log.backgroundTaskScheduling("Task \(identifier) completed with SUCCESS")
            task.setTaskCompleted(success: true)
        }

        @InjectService var uploadQueue: UploadQueue
        task.expirationHandler = {
            Log.backgroundTaskScheduling("Task \(identifier) EXPIRED", level: .error)
            uploadQueue.suspendAllOperations()
            uploadQueue.rescheduleRunningOperations()
            task.setTaskCompleted(success: false)
        }
    }

    func registerBackgroundTask(identifier: String) {
        let registered = scheduler.register(
            forTaskWithIdentifier: Constants.backgroundRefreshIdentifier,
            using: nil
        ) { task in
            buildBackgroundTask(task, identifier: Constants.backgroundRefreshIdentifier, scheduler: scheduler)
        }
        Log.backgroundTaskScheduling("Task \(Constants.backgroundRefreshIdentifier) registered ? \(registered)")
    }

    func handleBackgroundRefresh(completion: @escaping (Bool) -> Void) {
        Log.backgroundTaskScheduling("handleBackgroundRefresh")
        // User installed the app but never logged in
        @InjectService var accountManager: AccountManageable
        if accountManager.accounts.isEmpty {
            completion(false)
            return
        }

        Log.backgroundTaskScheduling("Enqueue new pictures")
        @InjectService var photoUploader: PhotoLibraryUploader
        photoUploader.scheduleNewPicturesForUpload()

        Log.backgroundTaskScheduling("Clean errors for all uploads")
        @InjectService var uploadQueue: UploadQueue
        uploadQueue.cleanNetworkAndLocalErrorsForAllOperations()

        Log.backgroundTaskScheduling("Reload operations in queue")
        uploadQueue.rebuildUploadQueueFromObjectsInRealm()

        Log.backgroundTaskScheduling("waitForCompletion")
        uploadQueue.waitForCompletion {
            completion(true)
        }
    }

    func scheduleBackgroundRefresh() {
        Log.backgroundTaskScheduling("scheduleBackgroundRefresh")
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
            try scheduler.submit(backgroundRefreshRequest)
            Log.backgroundTaskScheduling("scheduled task: \(backgroundRefreshRequest)")
            try scheduler.submit(longBackgroundRefreshRequest)
            Log.backgroundTaskScheduling("scheduled task: \(longBackgroundRefreshRequest)")

        } catch {
            Log.backgroundTaskScheduling("Error scheduling background task: \(error)", level: .error)
        }
    }
}
