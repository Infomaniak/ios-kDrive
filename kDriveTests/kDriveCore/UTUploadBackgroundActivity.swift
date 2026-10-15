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

import Alamofire
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
struct UTUploadBackgroundActivity {
    @Test func sharesProtectionAndRestartsAfterIdle() {
        var activities: [TestActivity] = []
        let owner = UploadBackgroundActivity(makeActivity: { delegate in
            let activity = TestActivity(delegate: delegate)
            activities.append(activity)
            return activity
        }, pauseUploads: {})

        owner.update(hasWork: true)
        owner.update(hasWork: true)
        #expect(activities.count == 1)
        #expect(activities[0].starts == 1)
        owner.update(hasWork: false)
        #expect(activities[0].ends == 1)
        owner.update(hasWork: true)
        #expect(activities.count == 2)
        owner.update(hasWork: false)
    }

    @Test func expirationWaitsForCleanupAndIgnoresDuplicates() async {
        var activities: [TestActivity] = []
        var cleanup: CheckedContinuation<Void, Never>?
        var cleanupCount = 0
        let owner = UploadBackgroundActivity(makeActivity: { delegate in
            let activity = TestActivity(delegate: delegate)
            activities.append(activity)
            return activity
        }, pauseUploads: {
            cleanupCount += 1
            await withCheckedContinuation { cleanup = $0 }
        })

        owner.update(hasWork: true)
        activities[0].delegate?.backgroundActivityExpiring()
        await drainCallbacks()
        #expect(cleanupCount == 1)
        #expect(activities[0].ends == 0)

        activities[0].delegate?.backgroundActivityExpiring()
        owner.update(hasWork: false)
        await drainCallbacks()
        #expect(cleanupCount == 1)
        #expect(activities[0].ends == 0)

        cleanup?.resume()
        await drainCallbacks()
        #expect(activities[0].ends == 1)

        owner.update(hasWork: true)
        #expect(activities.count == 2)
        activities[0].delegate?.backgroundActivityExpiring()
        await drainCallbacks()
        #expect(cleanupCount == 1)
        #expect(activities[1].ends == 0)
        owner.update(hasWork: false)
    }

    @Test(arguments: [false, true])
    func expirationChecksCurrentProtection(isProtectedAtExpiration: Bool) async {
        var activities: [TestActivity] = []
        var isProtected = !isProtectedAtExpiration
        var cleanupCount = 0
        let owner = UploadBackgroundActivity(makeActivity: { delegate in
            let activity = TestActivity(delegate: delegate)
            activities.append(activity)
            return activity
        }, shouldPauseUploads: {
            !isProtected
        }, pauseUploads: {
            cleanupCount += 1
        })

        owner.update(hasWork: true)
        isProtected = isProtectedAtExpiration
        activities[0].delegate?.backgroundActivityExpiring()
        await drainCallbacks()

        #expect(cleanupCount == (isProtectedAtExpiration ? 0 : 1))
        #expect(activities[0].ends == 1)

        activities[0].delegate?.backgroundActivityExpiring()
        await drainCallbacks()
        #expect(cleanupCount == (isProtectedAtExpiration ? 0 : 1))
        #expect(activities[0].ends == 1)

        owner.update(hasWork: true)
        #expect(activities.count == 2)
        owner.update(hasWork: false)
    }

    @Test(arguments: [false, true])
    func expirationReschedulesBothQueues(hasContinuedProtection: Bool) async throws {
        let savedFactories = SimpleResolver.sharedResolver.factories
        let savedServices = SimpleResolver.sharedResolver.store
        defer {
            TestTargetAssemblyHelper.clearRegisteredTypes()
            SimpleResolver.sharedResolver.factories = savedFactories
            SimpleResolver.sharedResolver.store = savedServices
        }
        TestTargetAssemblyHelper.clearRegisteredTypes()
        SimpleResolver.sharedResolver.factories = savedFactories
        SimpleResolver.sharedResolver.store(factory: Factory(type: AppContextServiceable.self) { _, _ in
            AppContextService(context: .appTests)
        })
        let configuration = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        let realm = try await Realm(configuration: configuration, actor: MainActor.shared)
        let database = TransactionExecutor(realmAccessible: RealmAccessor(
            realmURL: nil, realmConfiguration: configuration, excludeFromBackup: false
        ))
        SimpleResolver.sharedResolver.store(factory: Factory(type: Transactionable.self) { _, _ in
            database
        }, forCustomTypeIdentifier: kDriveDBID.uploads)
        let globalQueue = UploadQueue(queueCoordinationDelegate: nil)
        let photoQueue = UploadQueue(queueCoordinationDelegate: nil)
        for (identifier, queue) in [(UploadQueueID.global, globalQueue), (UploadQueueID.photo, photoQueue)] {
            queue.suspendAllOperations()
            SimpleResolver.sharedResolver.store(factory: Factory(type: UploadQueueable.self) { _, _ in queue },
                                                forCustomTypeIdentifier: identifier)
        }
        let notifications = ExpirationNotificationsHelper()
        SimpleResolver.sharedResolver.store(factory: Factory(type: NotificationsHelpable.self) { _, _ in notifications })
        SimpleResolver.sharedResolver.store(factory: Factory(type: AccountManageable.self) { _, _ in
            ExpirationAccountManager()
        })
        SimpleResolver.sharedResolver.store.removeAll()
        let service = UploadService()
        service.blockingRebuildUploadQueue()

        let completion = DynamicIslandTaskCompletion()
        let unavailableService = UnavailableDynamicIslandService()
        #expect(!unavailableService.isProtectingUploads)
        SimpleResolver.sharedResolver.store(factory: Factory(type: UploadNotifiable.self) { _, _ in service })
        let photoUploader = PhotoLibraryUploader()
        let settings = PhotoSyncSettings()
        settings.wifiSync = .wifiAndMobileData
        try database.writeTransaction { $0.add(settings) }
        SimpleResolver.sharedResolver.store(factory: Factory(type: PhotoLibraryUploadable.self) { _, _ in photoUploader })

        let file = UploadFile()
        file.name = "background-upload"
        file.userId = 1
        file.driveId = 1
        file.ownedByFileProvider = true
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data(count: Int(Constants.smallFileMaxSize)).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        file.pathURL = sourceURL
        let session = UploadingSessionTask()
        session.sessionExpiration = .distantFuture
        session.uploadSession = UploadSession()
        session.uploadSession?.uploadHost = "example.invalid"
        let chunk = UploadingChunkTask()
        chunk.range = 0 ... 0
        chunk.sha256 = "test-hash"
        session.chunkTasks.append(chunk)
        file.uploadingSession = session
        try database.writeTransaction { $0.add(file) }
        let networkConfiguration = URLSessionConfiguration.ephemeral
        networkConfiguration.protocolClasses = [ExpirationURLProtocol.self]
        let networkSession = URLSession(configuration: networkConfiguration)
        defer { networkSession.invalidateAndCancel() }
        let photo = UploadFile()
        photo.name = file.name
        photo.userId = file.userId
        photo.driveId = file.driveId
        photo.pathURL = sourceURL
        photo.ownedByFileProvider = true
        let photoSession = UploadingSessionTask()
        photoSession.sessionExpiration = .distantFuture
        photoSession.uploadSession = UploadSession()
        photoSession.uploadSession?.uploadHost = "example.invalid"
        let photoChunk = UploadingChunkTask()
        photoChunk.range = 0 ... 0
        photoChunk.sha256 = "test-hash"
        photoSession.chunkTasks.append(photoChunk)
        photo.uploadingSession = photoSession
        photo.setValue(UploadFileType.phAsset.rawValue, forKey: "rawType")
        try database.writeTransaction { $0.add(photo) }
        let operations = [file, photo].map { UploadOperation(uploadFileId: $0.id, urlSession: networkSession) }
        for (queue, operation) in zip([globalQueue, photoQueue], operations) {
            queue.operationQueue.addOperation(operation)
            queue.operationQueue.isSuspended = false
        }
        defer {
            globalQueue.cancelAllOperations()
            photoQueue.cancelAllOperations()
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while operations.contains(where: { $0.uploadTasks.isEmpty && !$0.isFinished }), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let networkTasks = try operations.map { operation in
            #expect(operation.isExecuting)
            var uploadTasks = operation.uploadTasks.makeIterator()
            return try #require(uploadTasks.next()?.value)
        }

        var activities: [TestActivity] = []
        let owner = UploadBackgroundActivity(makeActivity: { delegate in
            let activity = TestActivity(delegate: delegate)
            activities.append(activity)
            return activity
        }, shouldPauseUploads: {
            !(hasContinuedProtection && completion.result == nil)
        }, pauseUploads: {
            await service.pauseForBackgroundExpiration()
        })
        owner.update(hasWork: true)
        activities[0].delegate?.backgroundActivityExpiring()
        await drainCallbacks()
        if hasContinuedProtection {
            #expect(activities[0].ends == 1)
            #expect(notifications.pausedCount == 0)
            for (file, operation) in zip([file, photo], operations) {
                #expect(file.error == nil)
                #expect(operation.isExecuting)
            }
            for task in networkTasks {
                #expect(task.state == .running)
            }
            await completion.complete(with: .failure(ExpirationError.expired)) {
                await service.pauseForBackgroundExpiration()
            }
        } else {
            let cleanupDeadline = ContinuousClock.now.advanced(by: .seconds(5))
            while activities[0].ends == 0, ContinuousClock.now < cleanupDeadline {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        realm.refresh()
        #expect(activities[0].ends == 1)
        #expect(notifications.pausedCount == 1)
        #expect(globalQueue.isSuspended)
        #expect(photoQueue.isSuspended)
        for (file, operation) in zip([file, photo], operations) {
            #expect(operation.isFinished)
            #expect(file.error == .taskRescheduled)
            #expect(file.uploadingSession?.chunkTasks.first?.error == .taskRescheduled)
            #expect(!file.ownedByFileProvider)
        }
        for task in networkTasks {
            #expect(task.state == .canceling || task.state == .completed)
        }

        service.setPausedNotificationSent(false)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100 {
                group.addTask { await service.sendPausedNotificationIfNeeded() }
            }
        }
        #expect(notifications.pausedCount == 2)
        #expect(service.pausedNotificationSent)
    }

    private func drainCallbacks() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

private enum ExpirationError: Error {
    case expired
}

private final class ExpirationNotificationsHelper: NotificationsHelpable {
    @MainActor var pausedCount = 0

    func sendPausedUploadQueueNotification() {
        MainActor.assumeIsolated { pausedCount += 1 }
    }

    func askForPermissions() {}
    func registerCategories() {}
    func sendNotEnoughSpaceForUpload(filename: String) {}
    func sendGenericUploadError(filename: String, parentId: Int, error: DriveError, uploadFileId: String) {}
    func sendUploadDoneNotification(filename: String, parentId: Int) {}
    func sendUploadDoneNotification(uploadCount: Int, parentId: Int?) {}
    func sendDisconnectedNotification() {}
    func sendPhotoSyncErrorNotification() {}
    func sendFailedUpload(failedUpload: Int, totalUpload: Int) {}
    func sendDeleteUploadedPhotosNotification(photosToDelete: Int) {}
    func sendWrongPasswordNotification() {}
}

private final class ExpirationAccountManager: MockAccountManager {
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ExpirationURLProtocol.self]
        let apiFetcher = DriveApiFetcher()
        apiFetcher.authenticatedSession = Session(configuration: configuration)
        let drive = Drive()
        drive.id = 1
        drive.userId = 1
        currentDriveFileManager = DriveFileManager(drive: drive, apiFetcher: apiFetcher)
    }

    override func getTokenForUserId(_ id: Int) -> ApiToken? {
        ApiToken(accessToken: "test", expiresIn: 3600, refreshToken: "test", scope: "", tokenType: "Bearer",
                 userId: id, expirationDate: nil)
    }
}

private class ExpirationURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard request.httpMethod == "GET", let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]) else { return }
        let data = Data("""
        {"result":"success","data":{"expected_chunks":1,"received_chunks":0,"uploading_chunks":0,
        "failed_chunks":0,"expected_size":1,"uploaded_size":0,"chunks":[]}}
        """.utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class TestActivity: ExpiringActivityable {
    var starts = 0
    var ends = 0
    var shouldTerminate = false
    let delegate: ExpiringActivityDelegate?

    init(delegate: ExpiringActivityDelegate) {
        self.delegate = delegate
    }

    init(id: String, qos: DispatchQoS, delegate: ExpiringActivityDelegate?) {
        self.delegate = delegate
    }

    convenience init(id: String, delegate: ExpiringActivityDelegate?) {
        self.init(id: id, qos: .default, delegate: delegate)
    }

    func start() { starts += 1 }
    func endAll() { ends += 1 }
}
