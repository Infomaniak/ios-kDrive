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

import Foundation
import BackgroundTasks
import kDriveCore
import CocoaLumberjackSwift

extension AppDelegate {
    
    var bgScheduler :BGTaskScheduler {
        BGTaskScheduler.shared
    }
    
    /* To debug background tasks:
      Launch ->
      e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.infomaniak.background.refresh"]
      Force early termination ->
      e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.infomaniak.background.refresh"]
     */
    
    /// schedule background tasks
    func scheduleBackgroundRefresh() {
        // List pictures + upload files (+pictures) / photoKit
        let backgroundRefreshRequest = BGAppRefreshTaskRequest(identifier: Constants.backgroundRefreshIdentifier)
        backgroundRefreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)

        // Upload files (+pictures) / photokit
        let longBackgroundRefreshRequest = BGProcessingTaskRequest(identifier: Constants.longBackgroundRefreshIdentifier)
        longBackgroundRefreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        longBackgroundRefreshRequest.requiresNetworkConnectivity = true
        longBackgroundRefreshRequest.requiresExternalPower = true
        do {
            try bgScheduler.submit(backgroundRefreshRequest)
            try bgScheduler.submit(longBackgroundRefreshRequest)
        } catch {
            DDLogError("Error scheduling background task: \(error)")
        }
    }
    
    /// Register BackgroundTasks in scheduller for later
    func registerBackgroundTasks() {
        var registered = bgScheduler.register(forTaskWithIdentifier: Constants.backgroundRefreshIdentifier, using: nil) { task in
            self.scheduleBackgroundRefresh()

            task.expirationHandler = {
                UploadQueue.instance.suspendAllOperations()
                UploadQueue.instance.cancelRunningOperations()
                task.setTaskCompleted(success: false)
            }

            self.handleBackgroundRefresh { _ in
                task.setTaskCompleted(success: true)
            }
        }
        DDLogInfo("Task \(Constants.backgroundRefreshIdentifier) registered ? \(registered)")
        registered = bgScheduler.register(forTaskWithIdentifier: Constants.longBackgroundRefreshIdentifier, using: nil) { task in
            self.scheduleBackgroundRefresh()

            task.expirationHandler = {
                UploadQueue.instance.suspendAllOperations()
                UploadQueue.instance.cancelRunningOperations()
                task.setTaskCompleted(success: false)
            }

            self.handleBackgroundRefresh { _ in
                task.setTaskCompleted(success: true)
            }
        }
        DDLogInfo("Task \(Constants.longBackgroundRefreshIdentifier) registered ? \(registered)")
    }
    
}
