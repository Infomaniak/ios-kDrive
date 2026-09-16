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

import AppIntents
import FileProvider
import Foundation
import InfomaniakCore
import InfomaniakCoreDB
@testable import InfomaniakDI
@testable import kDriveCore
import RealmSwift
import Testing
import UniformTypeIdentifiers

@Suite(.serialized)
@MainActor
struct UTExternalFileIntents {
    @available(iOS 18.4, *)
    @Test func externalImportSurvivesSourceRemovalDatabaseReopenAndCacheCleanup() async throws {
        let fixture = try ExternalIntentFixture()
        defer { fixture.tearDown() }
        let contents = Data("External provider contents".utf8)
        let sourceURL = fixture.paths.groupDirectoryURL.appendingPathComponent("Original name.txt")
        try contents.write(to: sourceURL)
        let identifier = try FileEntityIdentifier.file(url: sourceURL)
        let entities = try await KDriveFileEntity.defaultQuery.entities(for: [identifier])
        let entity = try #require(entities.first)
        #expect(entities.count == 1)
        #expect(entity.isExternal)

        let intent = MoveFilesIntent()
        intent.entities = [entity]
        intent.destinationFolder = try await fixture.destinationEntity()
        _ = try await intent.perform()

        let reopenedRealm = try await Realm(configuration: fixture.uploads.configuration, actor: MainActor.shared)
        let upload = try #require(reopenedRealm.objects(UploadFile.self).first)
        #expect(reopenedRealm.objects(UploadFile.self).count == 1)
        #expect(fixture.uploads.queuedUploadIds == [upload.id])
        #expect(upload.name == sourceURL.lastPathComponent)
        #expect(upload.userId == fixture.drive.userId)
        #expect(upload.driveId == fixture.drive.id)
        #expect(upload.parentDirectoryId == fixture.destination.id)
        #expect(upload.uploadDate == nil)
        let importURL = try #require(upload.pathURL)
        let importDirectoryPath = fixture.paths.importDirectoryURL.standardizedFileURL.path + "/"
        try #require(importURL.standardizedFileURL.path.hasPrefix(importDirectoryPath))
        #expect(importURL.standardizedFileURL != sourceURL.standardizedFileURL)
        #expect(try Data(contentsOf: importURL) == contents)

        // Simulate losing access to the provider source before the queued upload starts.
        try FileManager.default.removeItem(at: sourceURL)
        let orphanURL = fixture.paths.importDirectoryURL.appendingPathComponent("orphan.txt")
        try Data("unused".utf8).write(to: orphanURL)
        FreeSpaceService().cleanOrphanImportFolderFiles(in: fixture.paths.importDirectoryURL)

        #expect(!FileManager.default.fileExists(atPath: orphanURL.path))
        #expect(try Data(contentsOf: importURL) == contents)
        #expect(upload.name == "Original name.txt")
    }

    @available(iOS 18.4, *)
    @Test func persistenceFailureIsReportedAndOnlyTheImportCopyIsRemoved() async throws {
        let fixture = try ExternalIntentFixture()
        defer { fixture.tearDown() }
        let contents = Data("Keep the original file".utf8)
        let sourceURL = fixture.paths.groupDirectoryURL.appendingPathComponent("Original.txt")
        try contents.write(to: sourceURL)
        let identifier = try FileEntityIdentifier.file(url: sourceURL)
        let entities = try await KDriveFileEntity.defaultQuery.entities(for: [identifier])
        let entity = try #require(entities.first)
        let intent = MoveFilesIntent()
        intent.entities = [entity]
        intent.destinationFolder = try await fixture.destinationEntity()
        let persistenceError = CocoaError(.fileWriteOutOfSpace)
        fixture.uploads.persistenceError = persistenceError

        await #expect(throws: persistenceError) {
            _ = try await intent.perform()
        }

        #expect(fixture.uploads.saveAttempts == 1)
        #expect(fixture.uploads.queuedUploadIds.isEmpty)
        #expect(fixture.uploads.getAllUploadingFilesFrozen().isEmpty)
        let remainingImports = try FileManager.default.contentsOfDirectory(
            at: fixture.paths.importDirectoryURL, includingPropertiesForKeys: nil
        )
        #expect(remainingImports.isEmpty)
        #expect(try Data(contentsOf: sourceURL) == contents)
    }

    @available(iOS 18.4, *)
    @Test func externalFoldersAreExcludedWithoutDroppingRegularFilesOrNativeFolders() async throws {
        let fixture = try ExternalIntentFixture()
        defer { fixture.tearDown() }
        let folderURL = fixture.paths.groupDirectoryURL.appendingPathComponent("External folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let fileURL = folderURL.appendingPathComponent("File without extension")
        try Data("regular file".utf8).write(to: fileURL)
        let folderIdentifier = try FileEntityIdentifier.file(url: folderURL)
        let fileIdentifier = try FileEntityIdentifier.file(url: fileURL)
        let nativeFolder = try await fixture.destinationEntity()

        let entities = try await KDriveFileEntity.defaultQuery.entities(for: [folderIdentifier, fileIdentifier, nativeFolder.id])

        #expect(entities.count == 2)
        #expect(!entities.contains { $0.id == folderIdentifier })
        #expect(entities.contains { $0.id == fileIdentifier && $0.isExternal })
        let resolvedFolder = try #require(entities.first { $0.id == nativeFolder.id })
        #expect(!resolvedFolder.isExternal)
        #expect(resolvedFolder.contentTypeIdentifier == UTType.folder.identifier)
        #expect(try resolvedFolder.resolveCache().file.isDirectory)
        #expect(fixture.uploads.getAllUploadingFilesFrozen().isEmpty)
    }
}

@available(iOS 18.4, *)
@MainActor
private final class ExternalIntentFixture {
    let paths: IntentPaths
    let uploads: IntentUploadDataSource
    let drive = Drive()
    let destination: File
    let driveFileManager: DriveFileManager
    private let savedFactories: [String: Factoryable]
    private let savedServices: [String: Any]

    init() throws {
        paths = try IntentPaths()
        uploads = IntentUploadDataSource(configuration: Realm.Configuration(
            fileURL: paths.groupDirectoryURL.appendingPathComponent("uploads.realm")
        ))
        savedFactories = SimpleResolver.sharedResolver.factories
        savedServices = SimpleResolver.sharedResolver.store
        SimpleResolver.sharedResolver.store.removeAll()
        let accountManager = MockAccountManager()
        SimpleResolver.sharedResolver.store(factory: Factory(type: AccountManageable.self) { _, _ in accountManager })
        SimpleResolver.sharedResolver.store(factory: Factory(type: AppContextServiceable.self) { _, _ in
            AppContextService(context: .appTests)
        })
        SimpleResolver.sharedResolver.store(factory: Factory(type: AppGroupPathProvidable.self) { [paths] _, _ in paths })
        SimpleResolver.sharedResolver.store(factory: Factory(type: UploadServiceDataSourceable.self) { [uploads] _, _ in
            uploads
        })
        SimpleResolver.sharedResolver.store(factory: Factory(type: Transactionable.self) { [uploads] _, _ in
            uploads.database
        }, forCustomTypeIdentifier: kDriveDBID.driveInfo)
        // Discard dependencies eagerly resolved before all test factories were installed.
        SimpleResolver.sharedResolver.store.removeAll()

        drive.id = Int.random(in: 100_000 ... 999_999_999)
        drive.userId = drive.id
        drive.objectId = DriveInfosManager.getObjectId(driveId: drive.id, userId: drive.userId)
        try uploads.database.writeTransaction { [drive] in $0.add(drive) }
        driveFileManager = DriveFileManager(drive: drive.freeze(), apiFetcher: DriveApiFetcher())
        accountManager.currentDriveFileManager = driveFileManager
        destination = File(id: 42, name: "Destination", driveId: drive.id)
        let rights = Rights()
        rights.canUpload = true
        destination.capabilities = rights
        try driveFileManager.database.writeTransaction { $0.add(destination) }
    }

    func destinationEntity() async throws -> KDriveFileEntity {
        let identifier = FileEntityIdentifier.draft(identifier: KDriveFileEntity.draftIdentifier(
            userId: drive.userId, driveId: drive.id, fileId: destination.id
        ))
        let entities = try await KDriveFileEntity.defaultQuery.entities(for: [identifier])
        return try #require(entities.first)
    }

    func tearDown() {
        SimpleResolver.sharedResolver.store.removeAll()
        SimpleResolver.sharedResolver.factories = savedFactories
        SimpleResolver.sharedResolver.store = savedServices
        _ = try? Realm.deleteFiles(for: driveFileManager.realmConfiguration)
        try? FileManager.default.removeItem(at: paths.groupDirectoryURL)
    }
}

private final class IntentPaths: AppGroupPathProvidable {
    let groupDirectoryURL: URL
    var importDirectoryURL: URL { groupDirectoryURL.appendingPathComponent("import", isDirectory: true) }
    var realmRootURL: URL { groupDirectoryURL }
    var cacheDirectoryURL: URL { groupDirectoryURL }
    var tmpDirectoryURL: URL { groupDirectoryURL }
    var openInPlaceDirectoryURL: URL? { nil }

    init() throws {
        groupDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: importDirectoryURL, withIntermediateDirectories: true)
    }

    init?(realmRootPath: String, appGroupIdentifier: String) { nil }
}

/// Persist the real UploadFile created by FileImportHelper, but never start network operations.
private final class IntentUploadDataSource: UploadServiceDataSourceable {
    let configuration: Realm.Configuration
    let database: TransactionExecutor
    private(set) var queuedUploadIds = [String]()
    private(set) var saveAttempts = 0
    var persistenceError: CocoaError?

    init(configuration: Realm.Configuration) {
        self.configuration = configuration
        database = TransactionExecutor(realmAccessible: RealmAccessor(
            realmURL: configuration.fileURL, realmConfiguration: configuration, excludeFromBackup: false
        ))
    }

    func saveToRealm(_ uploadFile: UploadFile, itemIdentifier: NSFileProviderItemIdentifier?,
                     addToQueue: Bool) throws -> UploadOperationable? {
        saveAttempts += 1
        if let persistenceError { throw persistenceError }
        let id = uploadFile.id
        try database.writeTransaction { $0.add(uploadFile) }
        if addToQueue { queuedUploadIds.append(id) }
        return nil
    }

    func getAllUploadingFilesFrozen() -> Results<UploadFile> {
        database.fetchResults(ofType: UploadFile.self) { $0.filter("uploadDate == nil").freeze() }
    }

    func getUploadingFile(fileProviderItemIdentifier: String) -> UploadFile? {
        getAllUploadingFilesFrozen().filter("fileProviderItemIdentifier == %@", fileProviderItemIdentifier).first
    }

    func getUploadedFile(fileProviderItemIdentifier: String) -> UploadFile? {
        getUploadedFiles(optionalPredicate: nil).filter("fileProviderItemIdentifier == %@", fileProviderItemIdentifier).first
    }

    func getUploadingFiles(withParent parentId: Int, userId: Int, driveId: Int) -> Results<UploadFile> {
        getUploadingFiles(userId: userId, driveIds: [driveId]).filter("parentDirectoryId == %d", parentId)
    }

    func getUploadingFiles(userId: Int, driveIds: [Int]) -> Results<UploadFile> {
        getAllUploadingFilesFrozen().filter("userId == %d AND driveId IN %@", userId, driveIds)
    }

    func getUploadedFiles(optionalPredicate: NSPredicate?) -> Results<UploadFile> {
        database.fetchResults(ofType: UploadFile.self) {
            $0.filter("uploadDate != nil").filter(optionalPredicate: optionalPredicate)
        }
    }

    func getUploadedFiles(writableRealm: Realm, optionalPredicate: NSPredicate?) -> Results<UploadFile> {
        writableRealm.objects(UploadFile.self).filter("uploadDate != nil").filter(optionalPredicate: optionalPredicate)
    }

    func getUploadedFilesIDs(optionalPredicate: NSPredicate?) -> [String] {
        getUploadedFiles(optionalPredicate: optionalPredicate).map(\.id)
    }
}
