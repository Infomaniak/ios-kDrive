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
import InfomaniakCore
import InfomaniakDI

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
    private static let activityShouldTerminateMessage = "Notified activity should terminate"

    @LazyInjectService private var scheduler: BGTaskScheduler
    @LazyInjectService private var accountManager: AccountManageable
    @LazyInjectService private var uploadService: UploadServiceable
    @LazyInjectService private var photoUploader: PhotoLibraryUploader

    public init() {
        // META: keep SonarCloud happy
    }

    public func registerBackgroundTasks() {
        Log.backgroundTaskScheduling("registerBackgroundTasks")
        registerBackgroundTask(identifier: Constants.backgroundRefreshIdentifier)
        registerBackgroundTask(identifier: Constants.longBackgroundRefreshIdentifier)
    }

    public func buildBackgroundTask(_ task: BGTask, identifier: String) {
        scheduleBackgroundRefresh()

        if UIApplication.shared.applicationState != .background {
            Log.backgroundTaskScheduling("Task \(identifier) only active in BACKGROUND")
            task.setTaskCompleted(success: true)
            return
        }

        handleBackgroundRefresh { _ in
            Log.backgroundTaskScheduling("Task \(identifier) completed with SUCCESS")
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            Log.backgroundTaskScheduling("Task \(identifier) EXPIRED", level: .error)
            uploadService.suspendAllOperations()
            uploadService.rescheduleRunningOperations()
            task.setTaskCompleted(success: false)
        }
    }

    func registerBackgroundTask(identifier: String) {
        let registered = scheduler.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            buildBackgroundTask(task, identifier: identifier)
        }
        Log.backgroundTaskScheduling("Task \(identifier) registered ? \(registered)")
    }

    func handleBackgroundRefresh(completion: @escaping (Bool) -> Void) {
        let expiringActivity = ExpiringActivity(id: UUID().uuidString, delegate: nil)
        expiringActivity.start()

        Log.backgroundTaskScheduling("handleBackgroundRefresh")
        // User installed the app but never logged in
        if expiringActivity.shouldTerminate || accountManager.accounts.isEmpty {
            Log.backgroundTaskScheduling(Self.activityShouldTerminateMessage, level: .error)
            completion(false)
            expiringActivity.endAll()
            return
        }

        Log.backgroundTaskScheduling("Enqueue new pictures")
        photoUploader.scheduleNewPicturesForUpload()

        guard !expiringActivity.shouldTerminate else {
            Log.backgroundTaskScheduling(Self.activityShouldTerminateMessage, level: .error)
            completion(false)
            expiringActivity.endAll()
            return
        }

        Log.backgroundTaskScheduling("Clean errors for all uploads")
        uploadService.cleanNetworkAndLocalErrorsForAllOperations()

        guard !expiringActivity.shouldTerminate else {
            Log.backgroundTaskScheduling(Self.activityShouldTerminateMessage, level: .error)
            completion(false)
            expiringActivity.endAll()
            return
        }

        Log.backgroundTaskScheduling("Reload operations in queue")
        uploadService.blockingRebuildUploadQueue()

        guard !expiringActivity.shouldTerminate else {
            Log.backgroundTaskScheduling(Self.activityShouldTerminateMessage, level: .error)
            completion(false)
            expiringActivity.endAll()
            return
        }

        Log.backgroundTaskScheduling("waitForCompletion")
        uploadService.waitForCompletion {
            Log.backgroundTaskScheduling("Background activity ended with success")
            completion(true)
            expiringActivity.endAll()
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
