/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation
import InfomaniakCore
import InfomaniakCoreDB
@testable import InfomaniakDI
@testable import kDriveCore
import Photos
import RealmSwift
import Testing

extension ResolverTests {
    @Suite
    @MainActor
    final class UTUploadMissingDestination {
        private static let userId = 1
        private static let driveId = 2
        private static let folderId = 3

        private var database: TransactionExecutor!
        private var retainedRealm: Realm!
        private var service: UploadService!
        private var photoUploader: PhotoUploaderStub!
        private var photoSync: PhotoSyncSpy!
        private var notifications: PhotoSyncNotificationsSpy!
        private var savedFactories: [String: Factoryable] = [:]
        private var savedServices: [String: Any] = [:]

        private func setUp() throws {
            savedFactories = SimpleResolver.sharedResolver.factories
            savedServices = SimpleResolver.sharedResolver.store
            TestTargetAssemblyHelper.clearRegisteredTypes()
            SimpleResolver.sharedResolver.factories = savedFactories
            SimpleResolver.sharedResolver.store(factory: Factory(type: AppContextServiceable.self) { _, _ in
                AppContextService(context: .appTests)
            })
            let configuration = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
            retainedRealm = try Realm(configuration: configuration)
            database = TransactionExecutor(realmAccessible: RealmAccessor(
                realmURL: nil, realmConfiguration: configuration, excludeFromBackup: false
            ))
            SimpleResolver.sharedResolver.store(factory: Factory(type: Transactionable.self) { [database] _, _ in
                database!
            }, forCustomTypeIdentifier: kDriveDBID.uploads)
            for identifier in [UploadQueueID.global, UploadQueueID.photo] {
                let queue = SuspendedUploadQueue(queueCoordinationDelegate: nil)
                SimpleResolver.sharedResolver.store(factory: Factory(type: UploadQueueable.self) { _, _ in queue },
                                                    forCustomTypeIdentifier: identifier)
            }

            let settings = PhotoSyncSettings()
            settings.userId = Self.userId
            settings.driveId = Self.driveId
            settings.parentDirectoryId = Self.folderId
            photoUploader = PhotoUploaderStub(frozenSettings: settings)
            photoSync = PhotoSyncSpy()
            notifications = PhotoSyncNotificationsSpy()
            SimpleResolver.sharedResolver.store(factory: Factory(type: PhotoLibraryUploadable.self) { [photoUploader] _, _ in
                photoUploader!
            })
            SimpleResolver.sharedResolver.store(factory: Factory(type: PhotoLibrarySyncable.self) { [photoSync] _, _ in
                photoSync!
            })
            SimpleResolver.sharedResolver.store(factory: Factory(type: NotificationsHelpable.self) { [notifications] _, _ in
                notifications!
            })
            // Discard instances eagerly resolved by the assembly before installing the test factories.
            SimpleResolver.sharedResolver.store.removeAll()
            service = UploadService()
            service.blockingRebuildUploadQueue()
        }

        private func tearDown() {
            service.blockingRebuildUploadQueue()
            service = nil
            retainedRealm = nil
            TestTargetAssemblyHelper.clearRegisteredTypes()
            SimpleResolver.sharedResolver.factories = savedFactories
            SimpleResolver.sharedResolver.store = savedServices
            savedFactories = [:]
            savedServices = [:]
        }

        @Test(arguments: [
            MissingDestination(userId: userId, driveId: driveId, folderId: folderId, disablesSync: true,
                               testDescription: "photo sync folder"),
            MissingDestination(userId: userId, driveId: driveId, folderId: folderId + 1, disablesSync: false,
                               testDescription: "other folder"),
            MissingDestination(userId: userId, driveId: driveId + 1, folderId: folderId, disablesSync: false,
                               testDescription: "same folder ID on another drive"),
            MissingDestination(userId: userId + 1, driveId: driveId, folderId: folderId, disablesSync: false,
                               testDescription: "same folder ID for another user")
        ])
        func missingDestinationCancelsUploadsAndDisablesMatchingPhotoSync(destination: MissingDestination) throws {
            try setUp()
            defer { tearDown() }
            let upload = UploadFile()
            upload.userId = destination.userId
            upload.driveId = destination.driveId
            upload.parentDirectoryId = destination.folderId
            let uploadId = upload.id
            try database.writeTransaction { $0.add(upload) }

            service.cancelUploadsForMissingDestination(parentId: destination.folderId,
                                                       userId: destination.userId,
                                                       driveId: destination.driveId)
            service.blockingRebuildUploadQueue()

            #expect(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: uploadId) == nil)
            #expect(photoSync.disableCount == (destination.disablesSync ? 1 : 0))
            #expect(notifications.photoSyncErrorCount == (destination.disablesSync ? 1 : 0))
        }
    }
}

struct MissingDestination: CustomTestStringConvertible, Sendable {
    let userId: Int
    let driveId: Int
    let folderId: Int
    let disablesSync: Bool
    let testDescription: String
}

private final class SuspendedUploadQueue: UploadQueue {
    override var shouldSuspendQueue: Bool { true }
}

private final class PhotoUploaderStub: PhotoLibraryUploadable {
    let frozenSettings: PhotoSyncSettings?

    init(frozenSettings: PhotoSyncSettings) {
        self.frozenSettings = frozenSettings
    }

    var liveSettings: PhotoSyncSettings? { frozenSettings }
    var isSyncEnabled: Bool { true }
    var isWifiOnly: Bool { false }
    func getUrl(for asset: PHAsset) async -> URL? { nil }
}

private final class PhotoSyncSpy: PhotoLibrarySyncable {
    private(set) var disableCount = 0

    func enableSync(_ liveNewSyncSettings: PhotoSyncSettings) {}
    func disableSync() { disableCount += 1 }
    func pauseSync(userId: Int) async {}
}

private final class PhotoSyncNotificationsSpy: NotificationsHelpable {
    private(set) var photoSyncErrorCount = 0

    func sendPhotoSyncErrorNotification() { photoSyncErrorCount += 1 }

    func askForPermissions() {}
    func registerCategories() {}
    func sendNotEnoughSpaceForUpload(filename: String) {}
    func sendGenericUploadError(filename: String, parentId: Int, error: DriveError, uploadFileId: String) {}
    func sendUploadDoneNotification(filename: String, parentId: Int) {}
    func sendUploadDoneNotification(uploadCount: Int, parentId: Int?) {}
    func sendPausedUploadQueueNotification() {}
    func sendDisconnectedNotification() {}
    func sendFailedUpload(failedUpload: Int, totalUpload: Int) {}
    func sendDeleteUploadedPhotosNotification(photosToDelete: Int) {}
    func sendWrongPasswordNotification() {}
}
