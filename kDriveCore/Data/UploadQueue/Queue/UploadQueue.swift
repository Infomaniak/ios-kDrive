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
        queue.maxConcurrentOperationCount = 4
        queue.isSuspended = shouldSuspendQueue
        return queue
    }()

    lazy var foregroundSession: URLSession = {
        let urlSessionConfiguration = URLSessionConfiguration.default
        urlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = true
        urlSessionConfiguration.allowsCellularAccess = true
        urlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        urlSessionConfiguration.httpMaximumConnectionsPerHost = 4 // This limit is not really respected because we are using http/2
        urlSessionConfiguration.timeoutIntervalForRequest = 60 * 2 // 2 minutes before timeout
        urlSessionConfiguration.networkServiceType = .default
        return URLSession(configuration: urlSessionConfiguration, delegate: nil, delegateQueue: nil)
    }()

    var fileUploadedCount = 0

    var bestSession: URLSession {
        if Bundle.main.isExtension {
            @InjectService var backgroundUploadSessionManager: BackgroundUploadSessionManager
            return backgroundUploadSessionManager.backgroundSession
        } else {
            return foregroundSession
        }
    }

    /// Should suspend operation queue based on network status
    var shouldSuspendQueue: Bool {
        let status = ReachabilityListener.instance.currentStatus
        return status == .offline || (status != .wifi && UserDefaults.shared.isWifiOnly)
    }

    /// Should suspend operation queue based on explicit `suspendAllOperations()` call
    var forceSuspendQueue = false

    var observations = (
        didUploadFile: [UUID: (UploadFile, File?) -> Void](),
        didChangeUploadCountInParent: [UUID: (Int, Int) -> Void](),
        didChangeUploadCountInDrive: [UUID: (Int, Int) -> Void]()
    )

    public init() {
        UploadQueueLog("Starting up")

        concurrentQueue.async {
            // Initialize operation queue with files from Realm, and make sure it restarts
            self.rebuildUploadQueueFromObjectsInRealm()
            self.resumeAllOperations()
        }

        // Observe network state change
        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] _ in
            let isSuspended = (shouldSuspendQueue || forceSuspendQueue)
            UploadQueueLog("observeNetworkChange :\(isSuspended)")
            self.operationQueue.isSuspended = isSuspended
        }
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

    // MARK: - Private methods

    private func compactRealmIfNeeded() {
        let compactingCondition: (Int, Int) -> (Bool) = { totalBytes, usedBytes in
            let fiftyMB = 50 * 1024 * 1024
            let compactingNeeded = (totalBytes > fiftyMB) && (Double(usedBytes) / Double(totalBytes)) < 0.5
            UploadQueueLog("Compacting uploads realm is needed ? \(compactingNeeded)")
            return compactingNeeded
        }

        let config = Realm.Configuration(
            fileURL: DriveFileManager.constants.rootDocumentsURL.appendingPathComponent("/uploads.realm"),
            schemaVersion: DriveFileManager.constants.currentUploadDbVersion,
            migrationBlock: DriveFileManager.constants.migrationBlock,
            shouldCompactOnLaunch: compactingCondition,
            objectTypes: [DownloadTask.self, UploadFile.self, PhotoSyncSettings.self]
        )
        do {
            _ = try Realm(configuration: config)
        } catch {
            UploadQueueLog("Failed to compact uploads realm: \(error)", level: .error)
        }
    }
}
