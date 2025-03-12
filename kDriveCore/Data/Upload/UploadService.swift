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

import Foundation
import InfomaniakCoreDB

// import RealmSwift
import InfomaniakDI

public enum UploadServiceBackgroundIdentifier {
    public static let base = ".backgroundsession.upload"
    public static let app: String = {
        return (Bundle.main.bundleIdentifier ?? "com.infomaniak.drive") + base
    }()
}

public final class UploadService {
    @LazyInjectService(customTypeIdentifier: UploadQueueID.global) var globalUploadQueue: UploadQueueable
    @LazyInjectService(customTypeIdentifier: UploadQueueID.photo) var photoUploadQueue: UploadQueueable

    @LazyInjectService(customTypeIdentifier: kDriveDBID.uploads) var uploadsDatabase: Transactionable
//    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var notificationHelper: NotificationsHelpable
    @LazyInjectService var appContextService: AppContextServiceable

    let serialQueue: DispatchQueue = {
        @LazyInjectService var appContextService: AppContextServiceable
        let autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = appContextService.isExtension ? .workItem : .inherit

        return DispatchQueue(
            label: "com.infomaniak.drive.upload-service",
            qos: .userInitiated,
            autoreleaseFrequency: autoreleaseFrequency
        )
    }()

    var fileUploadedCount = 0
    var observations = (
        didUploadFile: [UUID: (UploadFile, File?) -> Void](),
        didChangeUploadCountInParent: [UUID: (Int, Int) -> Void](),
        didChangeUploadCountInDrive: [UUID: (Int, Int) -> Void]()
    )

    public var operationCount: Int {
        globalUploadQueue.operationCount + photoUploadQueue.operationCount
    }

    public var pausedNotificationSent = false

    public init() {
        Task {
            self.rebuildUploadQueueFromObjectsInRealm()
        }
    }
}

extension UploadService: UploadServiceable {
    public var isSuspended: Bool {
        return globalUploadQueue.isSuspended && globalUploadQueue.isSuspended
    }

    public func rebuildUploadQueueFromObjectsInRealm() {
        let caller: StaticString = #function
        globalUploadQueue.rebuildUploadQueueFromObjectsInRealm(caller)
        photoUploadQueue.rebuildUploadQueueFromObjectsInRealm(caller)
    }

    public func suspendAllOperations() {
        globalUploadQueue.suspendAllOperations()
        photoUploadQueue.suspendAllOperations()
    }

    public func resumeAllOperations() {
        globalUploadQueue.resumeAllOperations()
        photoUploadQueue.resumeAllOperations()
    }

    public func waitForCompletion(_ completionHandler: @escaping () -> Void) {
        globalUploadQueue.waitForCompletion {
            self.photoUploadQueue.waitForCompletion {
                completionHandler()
            }
        }
    }

    public func retry(_ uploadFileId: String) {
        globalUploadQueue.retry(uploadFileId)
        photoUploadQueue.retry(uploadFileId)
    }

    public func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        globalUploadQueue.retryAllOperations(withParent: parentId, userId: userId, driveId: driveId)
        photoUploadQueue.retryAllOperations(withParent: parentId, userId: userId, driveId: driveId)
    }

    public func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        globalUploadQueue.cancelAllOperations(withParent: parentId, userId: userId, driveId: driveId)
        photoUploadQueue.cancelAllOperations(withParent: parentId, userId: userId, driveId: driveId)
    }

    public func rescheduleRunningOperations() {
        globalUploadQueue.rescheduleRunningOperations()
        photoUploadQueue.rescheduleRunningOperations()
    }

    public func cancelRunningOperations() {
        globalUploadQueue.cancelRunningOperations()
        photoUploadQueue.cancelRunningOperations()
    }

    public func cancel(uploadFileId: String) -> Bool {
        guard !globalUploadQueue.cancel(uploadFileId: uploadFileId) else {
            return true
        }

        return photoUploadQueue.cancel(uploadFileId: uploadFileId)
    }

    public func cleanNetworkAndLocalErrorsForAllOperations() {
        globalUploadQueue.cleanNetworkAndLocalErrorsForAllOperations()
        photoUploadQueue.cleanNetworkAndLocalErrorsForAllOperations()
    }
}
