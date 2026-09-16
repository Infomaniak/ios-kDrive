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
import InfomaniakLogin
@testable import kDriveCore
import RealmSwift
import Testing

@Suite(.serialized)
@MainActor
final class UTUploadAuthentication {
    private var database: TransactionExecutor!
    private var uploadDatabase: FailingUploadDatabase!
    private var retainedRealm: Realm!
    private var service: UploadService!
    private var accountManager: UploadAccountManager!
    private var globalQueue: SuspendedUploadQueue!
    private var photoQueue: SuspendedUploadQueue!
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
        uploadDatabase = FailingUploadDatabase(database: database)
        for identifier in [kDriveDBID.uploads, kDriveDBID.driveInfo] {
            SimpleResolver.sharedResolver.store(factory: Factory(type: Transactionable.self) { [uploadDatabase] _, _ in
                uploadDatabase!
            }, forCustomTypeIdentifier: identifier)
        }
        accountManager = UploadAccountManager()
        SimpleResolver.sharedResolver.store(factory: Factory(type: AccountManageable.self) { [accountManager] _, _ in
            accountManager!
        })
        SimpleResolver.sharedResolver.store(factory: Factory(type: UploadPublishable.self) { _, _ in
            SilentUploadPublisher()
        })
        globalQueue = SuspendedUploadQueue(delegate: nil)
        photoQueue = SuspendedUploadQueue(delegate: nil)
        SimpleResolver.sharedResolver.store(factory: Factory(type: UploadQueueable.self) { [globalQueue] _, _ in
            globalQueue!
        }, forCustomTypeIdentifier: UploadQueueID.global)
        SimpleResolver.sharedResolver.store(factory: Factory(type: UploadQueueable.self) { [photoQueue] _, _ in
            photoQueue!
        }, forCustomTypeIdentifier: UploadQueueID.photo)
        // Discard instances eagerly resolved by the assembly before installing the test factories.
        SimpleResolver.sharedResolver.store.removeAll()
        service = UploadService()
        SimpleResolver.sharedResolver.store(factory: Factory(type: UploadServiceable.self) { [service] _, _ in service! })
        SimpleResolver.sharedResolver.store(factory: Factory(type: UploadServiceDataSourceable.self) { [service] _, _ in
            service!
        })
        service.blockingRebuildUploadQueue()
    }

    private func tearDown() {
        service.blockingRebuildUploadQueue()
        globalQueue.cancelAllOperations()
        photoQueue.cancelAllOperations()
        service = nil
        retainedRealm = nil
        TestTargetAssemblyHelper.clearRegisteredTypes()
        SimpleResolver.sharedResolver.factories = savedFactories
        SimpleResolver.sharedResolver.store = savedServices
        savedFactories = [:]
        savedServices = [:]
    }

    @Test func disconnectRetainsOldPhotosHistoryAndOtherAccounts() throws {
        try setUp()
        defer { tearDown() }
        let photo = makeUpload(userId: 1, photo: true)
        let manual = makeUpload(userId: 1)
        let other = makeUpload(userId: 2, photo: true)
        let uploaded = makeUpload(userId: 1, photo: true)
        uploaded.uploadDate = Date()
        let settings = PhotoSyncSettings()
        settings.userId = 1
        settings.driveId = 1
        settings.lastSync = Date()
        let checkpoint = settings.lastSync
        try database.writeTransaction { realm in
            realm.add([photo, manual, other, uploaded])
            realm.add(settings)
        }

        try service.blockUploadsForAuthentication(userId: 1)

        #expect(database.fetchResults(ofType: UploadFile.self) { $0 }.count == 4)
        #expect(photo.isAuthenticationBlocked)
        #expect(manual.isAuthenticationBlocked)
        #expect(!other.isAuthenticationBlocked)
        #expect(!uploaded.isAuthenticationBlocked)
        #expect(uploaded.uploadDate != nil)
        #expect(settings.lastSync == checkpoint)
        #expect(try #require(photo.creationDate) < checkpoint)
        #expect(photo.assetLocalIdentifier == "retained-asset")
    }

    @Test func persistenceFailureThrowsBeforeAttemptingToEnqueue() throws {
        try setUp()
        defer { tearDown() }
        let file = makeUpload(userId: 1)
        accountManager.authenticatedUserIds = [1]
        let persistenceError = CocoaError(.fileWriteOutOfSpace)
        uploadDatabase.writeError = persistenceError
        defer { uploadDatabase.writeError = nil }

        #expect(throws: persistenceError) {
            try service.saveToRealm(file, itemIdentifier: nil, addToQueue: true)
        }

        #expect(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: file.id) == nil)
        #expect(globalQueue.operationCount == 0)
    }

    @Test func savedUploadWaitingForAuthenticationDoesNotThrow() throws {
        try setUp()
        defer { tearDown() }
        let file = makeUpload(userId: 1)

        let operation = try service.saveToRealm(file, itemIdentifier: nil, addToQueue: true)

        #expect(operation == nil)
        let savedFile = try #require(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: file.id))
        #expect(savedFile.isAuthenticationBlocked)
        #expect(savedFile.uploadDate == nil)
    }

    @Test func blockSurvivesDatabaseReopenAndAllRetryPaths() throws {
        try setUp()
        defer { tearDown() }
        let photo = makeUpload(userId: 1, photo: true)
        try database.writeTransaction { $0.add(photo) }
        try service.blockUploadsForAuthentication(userId: 1)
        let reopened = try Realm(configuration: retainedRealm.configuration)
        let reopenedPhoto = try #require(reopened.object(ofType: UploadFile.self, forPrimaryKey: photo.id))
        #expect(reopenedPhoto.isAuthenticationBlocked)

        service.cleanNetworkAndLocalErrorsForAllOperations()
        service.cleanWifiLimitationsErrorForAllOperationsAndRetry()
        service.retry(photo.id)
        service.retryAllOperations(withParent: 1, userId: 1, driveId: 1)
        service.blockingRebuildUploadQueue()
        retainedRealm.refresh()

        #expect(photo.isAuthenticationBlocked)
        #expect(photo.maxRetryCount == 0)
        #expect(photo.uploadDate == nil)
        #expect(globalQueue.addToQueue(uploadFile: photo, itemIdentifier: nil) == nil)
        #expect(globalQueue.operationCount + photoQueue.operationCount == 0)
    }

    @Test func lateCallbacksCannotOverwriteBlockOrDeleteRecord() async throws {
        try setUp()
        defer { tearDown() }
        let file = makeUpload(userId: 1)
        let id = file.id
        try database.writeTransaction { $0.add(file) }
        let operation = UploadOperation(uploadFileId: id)
        try service.blockUploadsForAuthentication(userId: 1)

        #expect(throws: DriveError.uploadAuthenticationRequired) {
            try operation.cleanUploadFileError()
        }
        #expect(throws: DriveError.uploadAuthenticationRequired) {
            try operation.transactionWithFile { $0.uploadDate = Date() }
        }
        #expect(operation.handleLocalErrors(error: DriveError.fileNotFound))
        try await operation.deleteUploadFile()
        let blockedFile = try #require(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: id))
        #expect(blockedFile.isAuthenticationBlocked)

        operation.cancel()
        try database.writeTransaction { realm in
            realm.object(ofType: UploadFile.self, forPrimaryKey: id)?.clearAuthenticationBlock()
        }
        #expect(throws: (any Error).self) {
            try operation.transactionWithFile { $0.error = .taskCancelled }
        }
        #expect(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: id)?.error == nil)
    }

    @Test func blockingStopsQueuedOperationAndPreservesSource() throws {
        try setUp()
        defer { tearDown() }
        let file = makeUpload(userId: 1)
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("pending upload".utf8).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        file.pathURL = sourceURL
        try database.writeTransaction { $0.add(file) }
        accountManager.authenticatedUserIds = [1]
        let operation = try #require(globalQueue.addToQueue(uploadFile: file, itemIdentifier: nil))
        #expect((service.globalUploadQueue as AnyObject) === globalQueue)
        #expect(globalQueue.getOperation(forUploadFileId: file.id) === operation)
        #expect(!file.isPhotoSyncUpload)

        try service.blockUploadsForAuthentication(userId: 1)

        #expect(operation.isCancelled)
        #expect(file.isAuthenticationBlocked)
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(file.uploadDate == nil)
    }

    @Test func pauseSyncRetainsSettingsAndPendingPhotos() async throws {
        try setUp()
        defer { tearDown() }
        let photo = makeUpload(userId: 1, photo: true)
        let id = photo.id
        let settings = PhotoSyncSettings()
        settings.userId = 1
        settings.lastSync = Date()
        let checkpoint = settings.lastSync
        try database.writeTransaction { realm in
            realm.add(photo)
            realm.add(settings)
        }
        let uploader = PhotoLibraryUploader()

        await uploader.pauseSync(userId: 1)

        #expect(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: id) != nil)
        #expect(uploader.frozenSettings?.lastSync == checkpoint)
        #expect(uploader.frozenSettings?.userId == 1)
    }

    @Test func photoSyncResetDoesNotPurgeAuthenticationBlockedPhotos() async throws {
        try setUp()
        defer { tearDown() }
        let photo = makeUpload(userId: 1, photo: true)
        let id = photo.id
        photo.blockForAuthentication()
        try database.writeTransaction { $0.add(photo) }

        try await service.cancelAnyPhotoSync()

        let retainedPhoto = try #require(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: id))
        #expect(retainedPhoto.isAuthenticationBlocked)
    }

    @Test func reconnectOnlyUnblocksAvailableDrivesOfAuthenticatedUser() async throws {
        try setUp()
        defer { tearDown() }
        let available = makeUpload(userId: 1)
        let missingDrive = makeUpload(userId: 1)
        missingDrive.driveId = 99
        let otherUser = makeUpload(userId: 2)
        let serverError = makeUpload(userId: 1)
        serverError.error = .quotaExceeded
        serverError.maxRetryCount = 0
        let ids = [available.id, missingDrive.id, otherUser.id, serverError.id]
        let drive = Drive()
        drive.id = 1
        drive.userId = 1
        drive.objectId = DriveInfosManager.getObjectId(driveId: 1, userId: 1)
        try database.writeTransaction { realm in
            realm.add([available, missingDrive, otherUser, serverError])
            realm.add(drive)
            for file in [available, missingDrive, otherUser] {
                file.blockForAuthentication()
            }
        }

        await service.resumeUploadsAfterAuthentication(userId: 1)
        let blocked = try #require(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: ids[0]))
        #expect(blocked.isAuthenticationBlocked)

        accountManager.authenticatedUserIds = [1]
        await service.resumeUploadsAfterAuthentication(userId: 1)

        let resumed = try #require(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: ids[0]))
        #expect(resumed.error == nil)
        #expect(resumed.maxRetryCount == UploadFile.defaultMaxRetryCount)
        for id in ids[1 ... 2] {
            let retained = try #require(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: id))
            #expect(retained.isAuthenticationBlocked)
        }
        #expect(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: ids[3])?.error == .quotaExceeded)
    }

    @Test func disablingSyncCancelsBlockedPhotosOnlyForItsAccount() async throws {
        try setUp()
        defer { tearDown() }
        let photo = makeUpload(userId: 1, photo: true)
        let otherAccountPhoto = makeUpload(userId: 2, photo: true)
        let manualUpload = makeUpload(userId: 1)
        let photoId = photo.id
        let otherPhotoId = otherAccountPhoto.id
        let manualId = manualUpload.id
        let settings = PhotoSyncSettings()
        settings.userId = 1
        try database.writeTransaction { realm in
            for file in [photo, otherAccountPhoto, manualUpload] {
                file.blockForAuthentication()
                realm.add(file)
            }
            realm.add(settings)
        }

        let uploader = PhotoLibraryUploader()
        uploader.disableSync()

        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while database.fetchObject(ofType: UploadFile.self, forPrimaryKey: photoId) != nil,
              ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(uploader.frozenSettings == nil)
        #expect(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: photoId) == nil)
        let retainedPhoto = try #require(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: otherPhotoId))
        #expect(retainedPhoto.isAuthenticationBlocked)
        let retainedManual = try #require(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: manualId))
        #expect(retainedManual.isAuthenticationBlocked)

        let drive = Drive()
        drive.id = 1
        drive.userId = 1
        try database.writeTransaction { $0.add(drive) }
        accountManager.authenticatedUserIds = [1]
        await service.resumeUploadsAfterAuthentication(userId: 1)
        #expect(database.fetchObject(ofType: UploadFile.self, forPrimaryKey: photoId) == nil)
    }

    private func makeUpload(userId: Int, photo: Bool = false) -> UploadFile {
        let file = UploadFile()
        file.userId = userId
        file.driveId = 1
        file.creationDate = Date(timeIntervalSince1970: 1)
        if photo {
            file.setValue("phAsset", forKey: "rawType")
            file.assetLocalIdentifier = "retained-asset"
        }
        return file
    }
}

private final class SuspendedUploadQueue: UploadQueue {
    override var shouldSuspendQueue: Bool { true }
}

private final class FailingUploadDatabase: Transactionable {
    let database: TransactionExecutor
    var writeError: CocoaError?

    init(database: TransactionExecutor) {
        self.database = database
    }

    func fetchObject<Element: Object, KeyType>(ofType type: Element.Type, forPrimaryKey key: KeyType) -> Element? {
        database.fetchObject(ofType: type, forPrimaryKey: key)
    }

    func fetchObject<Element: RealmFetchable>(
        ofType type: Element.Type,
        filtering: (Results<Element>) -> Element?
    ) -> Element? {
        database.fetchObject(ofType: type, filtering: filtering)
    }

    func fetchResults<Element: RealmFetchable>(
        ofType type: Element.Type,
        filtering: (Results<Element>) -> Results<Element>
    ) -> Results<Element> {
        database.fetchResults(ofType: type, filtering: filtering)
    }

    func writeTransaction(withRealm realmClosure: (Realm) throws -> Void) throws {
        try writeTransaction(withExpiringActivity: true, withRealm: realmClosure)
    }

    func writeTransaction(withExpiringActivity expiration: Bool, withRealm realmClosure: (Realm) throws -> Void) throws {
        if let writeError { throw writeError }
        try database.writeTransaction(withExpiringActivity: expiration, withRealm: realmClosure)
    }
}

private struct SilentUploadPublisher: UploadPublishable {
    func publishUploadCount(withParent parentId: Int, userId: Int, driveId: Int) {}
    func publishUploadCountInParent(parentId: Int, userId: Int, driveId: Int) {}
    func publishUploadCountInDrive(userId: Int, driveId: Int) {}
    func publishFileUploaded(result: UploadCompletionResult) {}
}

private final class UploadAccountManager: MockAccountManager {
    var authenticatedUserIds: Set<Int> = []

    override func getTokenForUserId(_ id: Int) -> ApiToken? {
        guard authenticatedUserIds.contains(id) else { return nil }
        return ApiToken(accessToken: "test", expiresIn: 3600, refreshToken: "test", scope: "", tokenType: "Bearer",
                        userId: id, expirationDate: nil)
    }
}
