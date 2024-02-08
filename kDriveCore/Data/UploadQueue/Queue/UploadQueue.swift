/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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
import InfomaniakCore
import InfomaniakDI
import RealmSwift
import Sentry

public final class UploadQueue {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var notificationHelper: NotificationsHelpable

    public static let backgroundBaseIdentifier = ".backgroundsession.upload"
    public static var backgroundIdentifier: String {
        return (Bundle.main.bundleIdentifier ?? "com.infomaniak.drive") + backgroundBaseIdentifier
    }

    public var pausedNotificationSent = false

    /// A serial queue to lock access to ivars an observations.
    let serialQueue = DispatchQueue(label: "com.infomaniak.drive.upload-sync", qos: .userInitiated)

    /// A concurrent queue.
    let concurrentQueue = DispatchQueue(label: "com.infomaniak.drive.upload-async",
                                        qos: .userInitiated,
                                        attributes: [.concurrent])

    /// Something to track an operation for a File ID
    let keyedUploadOperations = KeyedUploadOperationable()

    public lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "kDrive upload queue"
        queue.qualityOfService = .userInitiated

        // In extension to reduce memory footprint, we reduce drastically parallelism
        let parallelism: Int
        if Bundle.main.isExtension {
            parallelism = 2 // With 2 Operations max, and a chuck of 1MiB max, the UploadQueue can spike to max 4MiB.
        } else {
            parallelism = max(4, ProcessInfo.processInfo.activeProcessorCount)
        }

        queue.maxConcurrentOperationCount = parallelism
        queue.isSuspended = shouldSuspendQueue
        return queue
    }()

    lazy var foregroundSession: URLSession = {
        let urlSessionConfiguration = URLSessionConfiguration.default
        urlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = true
        urlSessionConfiguration.allowsCellularAccess = true
        urlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        urlSessionConfiguration
            .httpMaximumConnectionsPerHost = 4 // This limit is not really respected because we are using http/2
        urlSessionConfiguration.timeoutIntervalForRequest = 60 * 2 // 2 minutes before timeout
        urlSessionConfiguration.networkServiceType = .default
        return URLSession(configuration: urlSessionConfiguration, delegate: nil, delegateQueue: nil)
    }()

    var fileUploadedCount = 0

    var bestSession: URLSession {
        return foregroundSession
    }

    /// Should suspend operation queue based on network status
    var shouldSuspendQueue: Bool {
        #if ISEXTENSION
        // Explicitly disable upload queue in extension mode
        return true
        #else
        let status = ReachabilityListener.instance.currentStatus
        return status == .offline || (status != .wifi && UserDefaults.shared.isWifiOnly)
        #endif
    }

    /// Should suspend operation queue based on explicit `suspendAllOperations()` call
    var forceSuspendQueue = false

    var observations = (
        didUploadFile: [UUID: (UploadFile, File?) -> Void](),
        didChangeUploadCountInParent: [UUID: (Int, Int) -> Void](),
        didChangeUploadCountInDrive: [UUID: (Int, Int) -> Void]()
    )

    public init() {
        guard !Bundle.main.isExtension else {
            Log.uploadQueue("Disabled in extension mode", level: .warning)
            return
        }

        Log.uploadQueue("Starting up")

        concurrentQueue.async {
            // Initialize operation queue with files from Realm, and make sure it restarts
            self.rebuildUploadQueueFromObjectsInRealm()
            self.resumeAllOperations()
        }

        // Observe network state change
        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] status in
            guard let self else {
                return
            }

            let isSuspended = (shouldSuspendQueue || forceSuspendQueue)
            operationQueue.isSuspended = isSuspended
            Log.uploadQueue("observeNetworkChange :\(isSuspended)")
        }

        Log.uploadQueue("UploadQueue parallelism is:\(operationQueue.maxConcurrentOperationCount)")
    }

    // MARK: - Public methods

    public func getUploadingFiles(withParent parentId: Int,
                                  userId: Int,
                                  driveId: Int,
                                  using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        return getUploadingFiles(userId: userId, driveId: driveId, using: realm).filter("parentDirectoryId = %d", parentId)
    }

    public func getUploadingFiles(userId: Int,
                                  driveId: Int,
                                  using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        return realm.objects(UploadFile.self)
            .filter(NSPredicate(format: "uploadDate = nil AND userId = %d AND driveId = %d", userId, driveId))
            .sorted(byKeyPath: "taskCreationDate")
    }

    public func getUploadingFiles(userId: Int,
                                  driveIds: [Int],
                                  using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        return realm.objects(UploadFile.self)
            .filter(NSPredicate(format: "uploadDate = nil AND userId = %d AND driveId IN %@", userId, driveIds))
            .sorted(byKeyPath: "taskCreationDate")
    }

    public func getUploadedFiles(using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        return realm.objects(UploadFile.self).filter(NSPredicate(format: "uploadDate != nil"))
    }
}
