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

import Alamofire
import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import InfomaniakDI
import InfomaniakLogin
import RealmSwift
import SwiftRegex

public final class DriveFileManager {
    /// Something to centralize schema versioning
    enum RealmSchemaVersion {
        /// Current version of the Upload Realm
        static let upload: UInt64 = 19

        /// Current version of the Drive Realm
        static let drive: UInt64 = 9
    }

    public class DriveFileManagerConstants {
        public let driveObjectTypes = [
            File.self,
            Rights.self,
            FileActivity.self,
            FileCategory.self,
            FileConversion.self,
            FileVersion.self,
            FileExternalImport.self,
            ShareLink.self,
            ShareLinkCapabilities.self,
            DropBox.self,
            DropBoxCapabilities.self,
            DropBoxSize.self,
            DropBoxValidity.self
        ]
        private let fileManager = FileManager.default
        public let rootDocumentsURL: URL
        public let importDirectoryURL: URL
        public let groupDirectoryURL: URL
        public var cacheDirectoryURL: URL
        public var tmpDirectoryURL: URL
        public let openInPlaceDirectoryURL: URL?
        public let rootID = 1
        public let currentVersionCode = 1
        public lazy var migrationBlock = { [weak self] (migration: Migration, oldSchemaVersion: UInt64) in
            let currentUploadSchemaVersion = RealmSchemaVersion.upload

            // Log migration on Sentry
            SentryDebug.realmMigrationStartedBreadcrumb(
                form: oldSchemaVersion,
                to: currentUploadSchemaVersion,
                realmName: "Upload"
            )
            defer {
                SentryDebug.realmMigrationEndedBreadcrumb(
                    form: oldSchemaVersion,
                    to: currentUploadSchemaVersion,
                    realmName: "Upload"
                )
            }

            // Sanity check
            guard oldSchemaVersion < currentUploadSchemaVersion else {
                return
            }

            // Migration from version 2 to version 3
            if oldSchemaVersion < 3 {
                migration.enumerateObjects(ofType: UploadFile.className()) { _, newObject in
                    newObject!["maxRetryCount"] = 3
                }
            }
            // Migration to version 4 -> 7 is not needed
            // Migration from version 7 to version 9
            if oldSchemaVersion < 9 {
                migration.deleteData(forType: DownloadTask.className())
            }

            // Migration from version 9 to version 10
            if oldSchemaVersion < 10 {
                migration.enumerateObjects(ofType: UploadFile.className()) { _, newObject in
                    newObject!["conflictOption"] = ConflictOption.version.rawValue
                }
            }

            if oldSchemaVersion < 12 {
                migration.enumerateObjects(ofType: PhotoSyncSettings.className()) { _, newObject in
                    newObject!["photoFormat"] = PhotoFileFormat.heic.rawValue
                }
            }

            // Migration for Upload With Chunks
            if oldSchemaVersion < 14 {
                migration.deleteData(forType: UploadFile.className())
            }

            // Migration for UploadFile With dedicated fileProviderItemIdentifier and assetLocalIdentifier fields
            if oldSchemaVersion < 15 {
                migration.enumerateObjects(ofType: UploadFile.className()) { oldObject, newObject in
                    guard let newObject else {
                        return
                    }

                    // Try to migrate the assetLocalIdentifier if possible
                    let type: String? = oldObject?["rawType"] as? String ?? nil

                    switch type {
                    case UploadFileType.phAsset.rawValue:
                        // The object was from a phAsset source, the id has to be the `LocalIdentifier`
                        let oldAssetIdentifier: String? = oldObject?["id"] as? String ?? nil

                        newObject["assetLocalIdentifier"] = oldAssetIdentifier
                        newObject["fileProviderItemIdentifier"] = nil

                        // Making sure the ID is unique, and not a PHAsset identifier
                        newObject["id"] = UUID().uuidString

                    default:
                        // We cannot infer anything, all to nil
                        newObject["assetLocalIdentifier"] = nil
                        newObject["fileProviderItemIdentifier"] = nil
                    }
                }
            }

            // Migration for UploadFile renamed initiatedFromFileManager into ownedByFileProvider
            if oldSchemaVersion < 19 {
                migration.enumerateObjects(ofType: UploadFile.className()) { oldObject, newObject in
                    guard let newObject else {
                        return
                    }

                    // Try to migrate the initiatedFromFileManager if possible
                    let initiatedFromFileManager: Bool? = oldObject?["initiatedFromFileManager"] as? Bool ?? false
                    newObject["ownedByFileProvider"] = initiatedFromFileManager
                }
            }
        }

        /// Path of the upload DB
        public lazy var uploadsRealmURL = rootDocumentsURL.appendingPathComponent("uploads.realm")

        public lazy var uploadsRealmConfiguration = Realm.Configuration(
            fileURL: uploadsRealmURL,
            schemaVersion: RealmSchemaVersion.upload,
            migrationBlock: migrationBlock,
            objectTypes: [DownloadTask.self,
                          PhotoSyncSettings.self,
                          UploadSession.self,
                          UploadFile.self,
                          UploadingChunkTask.self,
                          UploadedChunk.self,
                          UploadingSessionTask.self]
        )

        /// realm db used for file upload
        public var uploadsRealm: Realm {
            // Change file metadata after creation of the realm file.
            defer {
                // Exclude "upload file realm" and custom cache from system backup.
                var metadata = URLResourceValues()
                metadata.isExcludedFromBackup = true
                do {
                    try uploadsRealmURL.setResourceValues(metadata)
                    try cacheDirectoryURL.setResourceValues(metadata)
                } catch {
                    DDLogError(error)
                }
            }

            do {
                return try Realm(configuration: uploadsRealmConfiguration)
            } catch {
                // We can't recover from this error but at least we report it correctly on Sentry
                Logging.reportRealmOpeningError(error, realmConfiguration: uploadsRealmConfiguration)
            }
        }

        init() {
            @InjectService var pathProvider: AppGroupPathProvidable
            groupDirectoryURL = pathProvider.groupDirectoryURL
            rootDocumentsURL = pathProvider.realmRootURL
            importDirectoryURL = pathProvider.importDirectoryURL
            tmpDirectoryURL = pathProvider.tmpDirectoryURL
            cacheDirectoryURL = pathProvider.cacheDirectoryURL
            openInPlaceDirectoryURL = pathProvider.openInPlaceDirectoryURL

            DDLogInfo(
                "App working path is: \(fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.absoluteString ?? "")"
            )
            DDLogInfo("Group container path is: \(groupDirectoryURL.absoluteString)")
        }
    }

    public static let constants = DriveFileManagerConstants()

    private let fileManager = FileManager.default
    public static var favoriteRootFile: File {
        return File(id: -1, name: "Favorite")
    }

    public static var trashRootFile: File {
        return File(id: -2, name: "Trash")
    }

    public static var sharedWithMeRootFile: File {
        return File(id: -3, name: "Shared with me")
    }

    public static var mySharedRootFile: File {
        return File(id: -4, name: "My shares")
    }

    public static var searchFilesRootFile: File {
        return File(id: -5, name: "Search")
    }

    public static var homeRootFile: File {
        return File(id: -6, name: "Home")
    }

    public static var lastModificationsRootFile: File {
        return File(id: -7, name: "Recent changes")
    }

    public static var lastPicturesRootFile: File {
        return File(id: -8, name: "Images")
    }

    public static var offlineRoot: File {
        let offlineRoot = File(id: -9, name: "Offline")
        offlineRoot.fullyDownloaded = true
        return offlineRoot
    }

    public func getCachedRootFile(freeze: Bool = true, using realm: Realm? = nil) -> File {
        if let root = getCachedFile(id: DriveFileManager.constants.rootID, freeze: false) {
            if root.name != drive.name {
                let realm = realm ?? getRealm()
                realm.refresh()

                try? realm.safeWrite {
                    root.name = drive.name
                }
            }
            return freeze ? root.freeze() : root
        } else {
            return File(id: DriveFileManager.constants.rootID, name: drive.name)
        }
    }

    // autorelease frequecy so cleaner serialized realm base
    let backgroundQueue = DispatchQueue(label: "background-db", autoreleaseFrequency: .workItem)
    public let realmConfiguration: Realm.Configuration
    public private(set) var drive: Drive
    public let apiFetcher: DriveApiFetcher

    private var didUpdateFileObservers = [UUID: (File) -> Void]()

    /// Path of the main Realm DB
    var realmURL: URL

    init(drive: Drive, apiFetcher: DriveApiFetcher) {
        self.drive = drive
        self.apiFetcher = apiFetcher
        realmURL = DriveFileManager.constants.rootDocumentsURL.appendingPathComponent("\(drive.userId)-\(drive.id).realm")

        realmConfiguration = Realm.Configuration(
            fileURL: realmURL,
            schemaVersion: RealmSchemaVersion.drive,
            migrationBlock: { migration, oldSchemaVersion in
                let currentDriveSchemeVersion = RealmSchemaVersion.drive

                // Log migration on Sentry
                SentryDebug.realmMigrationStartedBreadcrumb(
                    form: oldSchemaVersion,
                    to: currentDriveSchemeVersion,
                    realmName: "Drive"
                )
                defer {
                    SentryDebug.realmMigrationEndedBreadcrumb(
                        form: oldSchemaVersion,
                        to: currentDriveSchemeVersion,
                        realmName: "Drive"
                    )
                }

                // Sanity check
                guard oldSchemaVersion < currentDriveSchemeVersion else {
                    return
                }

                // Models older than v5 are cleared, so any migration before that is moot.
                if oldSchemaVersion < 5 {
                    // Remove rights
                    migration.deleteData(forType: Rights.className())
                    // Delete file categories for migration
                    migration.deleteData(forType: FileCategory.className())
                }
                if oldSchemaVersion < 7 {
                    // Migrate file category
                    migration.enumerateObjects(ofType: FileCategory.className()) { oldObject, newObject in
                        newObject?["categoryId"] = oldObject?["id"]
                        newObject?["addedAt"] = oldObject?["addedToFileAt"]
                        newObject?["isGeneratedByAI"] = oldObject?["isGeneratedByIA"]
                        newObject?["userValidation"] = oldObject?["IACategoryUserValidation"]
                    }
                    // Migrate rights
                    migration.enumerateObjects(ofType: Rights.className()) { oldObject, newObject in
                        newObject?["canShow"] = oldObject?["show"] ?? false
                        newObject?["canRead"] = oldObject?["read"] ?? false
                        newObject?["canWrite"] = oldObject?["write"] ?? false
                        newObject?["canShare"] = oldObject?["share"] ?? false
                        newObject?["canLeave"] = oldObject?["leave"] ?? false
                        newObject?["canDelete"] = oldObject?["delete"] ?? false
                        newObject?["canRename"] = oldObject?["rename"] ?? false
                        newObject?["canMove"] = oldObject?["move"] ?? false
                        newObject?["canCreateDirectory"] = oldObject?["createNewFolder"] ?? false
                        newObject?["canCreateFile"] = oldObject?["createNewFile"] ?? false
                        newObject?["canUpload"] = oldObject?["uploadNewFile"] ?? false
                        newObject?["canMoveInto"] = oldObject?["moveInto"] ?? false
                        newObject?["canBecomeDropbox"] = oldObject?["canBecomeCollab"] ?? false
                        newObject?["canBecomeSharelink"] = oldObject?["canBecomeLink"] ?? false
                        newObject?["canUseFavorite"] = oldObject?["canFavorite"] ?? false
                        newObject?["canUseTeam"] = false
                    }
                    // Migrate file
                    migration.enumerateObjects(ofType: File.className()) { oldObject, newObject in
                        newObject?["sortedName"] = oldObject?["nameNaturalSorting"]
                        newObject?["extensionType"] = oldObject?["rawConvertedType"]
                        newObject?["_capabilities"] = oldObject?["rights"] as? Rights
                        newObject?["rawType"] = oldObject?["type"]
                        newObject?["rawStatus"] = oldObject?["status"]
                        newObject?["hasOnlyoffice"] = oldObject?["onlyOffice"]
                        newObject?["addedAt"] = Date(timeIntervalSince1970: TimeInterval(oldObject?["createdAt"] as? Int ?? 0))
                        newObject?["lastModifiedAt"] =
                            Date(timeIntervalSince1970: TimeInterval(oldObject?["lastModifiedAt"] as? Int ?? 0))
                        if let createdAt = oldObject?["fileCreatedAt"] as? Int {
                            newObject?["createdAt"] = Date(timeIntervalSince1970: TimeInterval(createdAt))
                        }
                        if let deletedAt = oldObject?["deletedAt"] as? Int {
                            newObject?["deletedAt"] = Date(timeIntervalSince1970: TimeInterval(deletedAt))
                        }
                    }
                }
                if oldSchemaVersion < 8 {
                    migration.enumerateObjects(ofType: FileActivity.className()) { oldObject, newObject in
                        newObject?["newPath"] = oldObject?["pathNew"]
                        if let createdAt = oldObject?["createdAt"] as? Int {
                            newObject?["createdAt"] = Date(timeIntervalSince1970: TimeInterval(createdAt))
                        }
                    }
                }
            },
            objectTypes: DriveFileManager.constants.driveObjectTypes
        )

        // Only compact in the background
        /* if !Constants.isInExtension && UIApplication.shared.applicationState == .background {
             compactRealmsIfNeeded()
         } */

        // Init root file
        let realm = getRealm()
        if getCachedFile(id: DriveFileManager.constants.rootID, freeze: false, using: realm) == nil {
            let rootFile = getCachedRootFile(using: realm)
            try? realm.safeWrite {
                realm.add(rootFile)
            }
        }
        Task {
            try await initRoot()
        }
    }

    private func compactRealmsIfNeeded() {
        DDLogInfo("Trying to compact realms if needed")
        let compactingCondition: (Int, Int) -> (Bool) = { totalBytes, usedBytes in
            let fiftyMB = 50 * 1024 * 1024
            let compactingNeeded = (totalBytes > fiftyMB) && (Double(usedBytes) / Double(totalBytes)) < 0.5
            return compactingNeeded
        }

        let config = Realm.Configuration(
            fileURL: DriveFileManager.constants.rootDocumentsURL.appendingPathComponent("/DrivesInfos.realm"),
            shouldCompactOnLaunch: compactingCondition,
            objectTypes: [
                Drive.self,
                DrivePreferences.self,
                DriveUsersCategories.self,
                DriveTeamsCategories.self,
                DriveUser.self,
                Team.self,
                Category.self,
                CategoryRights.self
            ]
        )
        do {
            _ = try Realm(configuration: config)
        } catch {
            DDLogError("Failed to compact drive infos realm: \(error)")
        }

        let files = (try? fileManager
            .contentsOfDirectory(at: DriveFileManager.constants.rootDocumentsURL, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "realm" {
            do {
                let realmConfiguration = Realm.Configuration(
                    fileURL: file,
                    deleteRealmIfMigrationNeeded: true,
                    shouldCompactOnLaunch: compactingCondition,
                    objectTypes: [File.self, Rights.self, FileActivity.self]
                )
                _ = try Realm(configuration: realmConfiguration)
            } catch {
                DDLogError("Failed to compact realm: \(error)")
            }
        }
    }

    public func getRealm() -> Realm {
        // Change file metadata after creation of the realm file.
        defer {
            // Exclude "file cache realm" from system backup.
            var metadata = URLResourceValues()
            metadata.isExcludedFromBackup = true
            do {
                try realmURL.setResourceValues(metadata)
            } catch {
                DDLogError(error)
            }
            DDLogInfo("realmURL : \(realmURL)")
        }

        do {
            return try Realm(configuration: realmConfiguration)
        } catch {
            // We can't recover from this error but at least we report it correctly on Sentry
            Logging.reportRealmOpeningError(error, realmConfiguration: realmConfiguration)
        }
    }

    /// Delete all drive data cache for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - driveId: Drive ID (`nil` if all user drives)
    public static func deleteUserDriveFiles(userId: Int, driveId: Int? = nil) {
        let files = (try? FileManager.default
            .contentsOfDirectory(at: DriveFileManager.constants.rootDocumentsURL, includingPropertiesForKeys: nil))
        files?.forEach { file in
            if let matches = Regex(pattern: "(\\d+)-(\\d+).realm.*")?.firstMatch(in: file.lastPathComponent), matches.count > 2 {
                let fileUserId = matches[1]
                let fileDriveId = matches[2]
                if Int(fileUserId) == userId && (driveId == nil || Int(fileDriveId) == driveId) {
                    DDLogInfo("Deleting file: \(file.lastPathComponent)")
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    public func getCachedFile(id: Int, freeze: Bool = true, using realm: Realm? = nil) -> File? {
        let realm = realm ?? getRealm()
        realm.refresh()

        guard let file = realm.object(ofType: File.self, forPrimaryKey: id), !file.isInvalidated else {
            return nil
        }
        return freeze ? file.freeze() : file
    }

    public func initRoot() async throws {
        let root = try await file(id: DriveFileManager.constants.rootID, forceRefresh: true)
        _ = try await files(in: root.proxify())
    }

    public func files(in directory: ProxyFile, page: Int = 1, sortType: SortType = .nameAZ,
                      forceRefresh: Bool = false) async throws -> (files: [File], moreComing: Bool) {
        let fetchFiles: () async throws -> ([File], Int?)
        if directory.isRoot {
            fetchFiles = {
                let (children, responseAt) = try await self.apiFetcher
                    .rootFiles(drive: self.drive, page: page, sortType: sortType)
                return (children, responseAt)
            }
        } else {
            fetchFiles = {
                let (children, responseAt) = try await self.apiFetcher.files(in: directory, page: page, sortType: sortType)
                return (children, responseAt)
            }
        }
        return try await files(in: directory, fetchFiles: fetchFiles,
                               page: page, sortType: sortType, keepProperties: [.standard, .extras], forceRefresh: forceRefresh)
    }

    private func remoteFiles(in directory: ProxyFile,
                             fetchFiles: () async throws -> ([File], Int?),
                             page: Int,
                             sortType: SortType,
                             keepProperties: FilePropertiesOptions) async throws -> (files: [File], moreComing: Bool) {
        // Get children from API
        let (children, responseAt) = try await fetchFiles()
        let realm = getRealm()
        // Keep cached properties for children
        for child in children {
            keepCacheAttributesForFile(newFile: child, keepProperties: keepProperties, using: realm)
        }

        let managedParent = try directory.resolve(using: realm)
        // Update parent
        try realm.write {
            managedParent.responseAt = responseAt ?? Int(Date().timeIntervalSince1970)
            if children.count < Endpoint.itemsPerPage {
                managedParent.versionCode = DriveFileManager.constants.currentVersionCode
                managedParent.fullyDownloaded = true
            }
            realm.add(children, update: .modified)
            // ⚠️ this is important because we are going to add all the children again. However, failing to start the request with
            // the first page will result in an undefined behavior.
            if page == 1 {
                managedParent.children.removeAll()
            }
            managedParent.children.insert(objectsIn: children)
        }

        return (
            getLocalSortedDirectoryFiles(directory: managedParent, sortType: sortType),
            children.count == Endpoint.itemsPerPage
        )
    }

    private func files(in directory: ProxyFile,
                       fetchFiles: () async throws -> ([File], Int?),
                       page: Int,
                       sortType: SortType,
                       keepProperties: FilePropertiesOptions,
                       forceRefresh: Bool) async throws -> (files: [File], moreComing: Bool) {
        if let cachedParent = getCachedFile(id: directory.id, freeze: false),
           // We have cache and we show it before fetching activities OR we are not connected to internet and we show what we have
           // anyway
           (cachedParent.canLoadChildrenFromCache && !forceRefresh) || ReachabilityListener.instance.currentStatus == .offline {
            return (getLocalSortedDirectoryFiles(directory: cachedParent, sortType: sortType), false)
        } else {
            return try await remoteFiles(
                in: directory,
                fetchFiles: fetchFiles,
                page: page,
                sortType: sortType,
                keepProperties: keepProperties
            )
        }
    }

    public func file(id: Int, forceRefresh: Bool = false) async throws -> File {
        if let cachedFile = getCachedFile(id: id),
           // We have cache and we show it before fetching activities OR we are not connected to internet and we show what we have
           // anyway
           (cachedFile.responseAt > 0 && !forceRefresh) || ReachabilityListener.instance.currentStatus == .offline {
            return cachedFile
        } else {
            let (file, _) = try await apiFetcher.fileInfo(ProxyFile(driveId: drive.id, id: id))

            let realm = getRealm()

            // Keep cached properties for file
            keepCacheAttributesForFile(newFile: file, keepProperties: [.standard], using: realm)

            // Update file in Realm
            try? realm.safeWrite {
                realm.add(file, update: .modified)
            }

            return file.freeze()
        }
    }

    public func favorites(page: Int = 1, sortType: SortType = .nameAZ,
                          forceRefresh: Bool = false) async throws -> (files: [File], moreComing: Bool) {
        try await files(in: getManagedFile(from: DriveFileManager.favoriteRootFile).proxify(),
                        fetchFiles: {
                            let favorites = try await apiFetcher.favorites(drive: drive, page: page, sortType: sortType)
                            return (favorites, nil)
                        },
                        page: page,
                        sortType: sortType,
                        keepProperties: [.standard, .extras],
                        forceRefresh: forceRefresh)
    }

    public func mySharedFiles(page: Int = 1, sortType: SortType = .nameAZ,
                              forceRefresh: Bool = false) async throws -> (files: [File], moreComing: Bool) {
        try await files(in: getManagedFile(from: DriveFileManager.mySharedRootFile).proxify(),
                        fetchFiles: {
                            let mySharedFiles = try await apiFetcher.mySharedFiles(drive: drive, page: page, sortType: sortType)
                            return (mySharedFiles, nil)
                        },
                        page: page,
                        sortType: sortType,
                        keepProperties: [.standard, .path, .version],
                        forceRefresh: forceRefresh)
    }

    public func getAvailableOfflineFiles(sortType: SortType = .nameAZ) -> [File] {
        let offlineFiles = getRealm().objects(File.self)
            .filter(NSPredicate(format: "isAvailableOffline = true"))
            .sorted(by: [sortType.value.sortDescriptor]).freeze()

        return offlineFiles.map { $0.freeze() }
    }

    public func removeSearchChildren() {
        let realm = getRealm()
        let searchRoot = getManagedFile(from: DriveFileManager.searchFilesRootFile, using: realm)
        try? realm.write {
            searchRoot.fullyDownloaded = false
            searchRoot.children.removeAll()
        }
    }

    public func searchFile(query: String? = nil,
                           date: DateInterval? = nil,
                           fileType: ConvertedType? = nil,
                           categories: [Category],
                           belongToAllCategories: Bool,
                           page: Int = 1,
                           sortType: SortType = .nameAZ) async throws -> Bool {
        do {
            return try await remoteFiles(in: DriveFileManager.searchFilesRootFile.proxify(),
                                         fetchFiles: {
                                             let searchResults = try await apiFetcher.searchFiles(
                                                 drive: drive,
                                                 query: query,
                                                 date: date,
                                                 fileTypes: [fileType].compactMap { $0 },
                                                 categories: categories,
                                                 belongToAllCategories: belongToAllCategories,
                                                 page: page,
                                                 sortType: sortType
                                             )
                                             return (searchResults, nil)
                                         },
                                         page: page,
                                         sortType: sortType,
                                         keepProperties: [.standard, .extras]).moreComing
        } catch {
            if error.asAFError?.isExplicitlyCancelledError == true {
                throw DriveError.searchCancelled
            } else {
                throw DriveError.networkError
            }
        }
    }

    public func searchOffline(query: String? = nil,
                              date: DateInterval? = nil,
                              fileType: ConvertedType? = nil,
                              categories: [Category],
                              belongToAllCategories: Bool,
                              sortType: SortType = .nameAZ) -> Results<File> {
        let realm = getRealm()
        var searchResults = realm.objects(File.self).filter("id > 0")
        if let query, !query.isBlank {
            searchResults = searchResults.filter(NSPredicate(format: "name CONTAINS[cd] %@", query))
        }

        if let date {
            searchResults = searchResults.filter(NSPredicate(
                format: "lastModifiedAt >= %d && lastModifiedAt <= %d",
                Int(date.start.timeIntervalSince1970),
                Int(date.end.timeIntervalSince1970)
            ))
        }

        if let fileType {
            if fileType == .folder {
                searchResults = searchResults.filter(NSPredicate(format: "rawType == \"dir\""))
            } else {
                searchResults = searchResults.filter(NSPredicate(format: "extensionType == %@", fileType.rawValue))
            }
        }

        if !categories.isEmpty {
            let predicate: NSPredicate
            if belongToAllCategories {
                let predicates = categories.map { NSPredicate(format: "ANY categories.id = %d", $0.id) }
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            } else {
                predicate = NSPredicate(format: "ANY categories.id IN %@", categories.map(\.id))
            }
            searchResults = searchResults.filter(predicate)
        }

        return searchResults.sorted(by: [sortType.value.sortDescriptor])
    }

    public func setFileAvailableOffline(file: File, available: Bool, completion: @escaping (Error?) -> Void) {
        let realm = getRealm()
        guard let file = getCachedFile(id: file.id, freeze: false, using: realm) else {
            completion(DriveError.fileNotFound)
            return
        }
        let oldUrl = file.localUrl
        let isLocalVersionOlderThanRemote = file.isLocalVersionOlderThanRemote
        if available {
            try? realm.safeWrite {
                file.isAvailableOffline = true
            }
            if !isLocalVersionOlderThanRemote {
                do {
                    try fileManager.createDirectory(at: file.localContainerUrl, withIntermediateDirectories: true)
                    try fileManager.moveItem(at: oldUrl, to: file.localUrl)
                    notifyObserversWith(file: file)
                    completion(nil)
                } catch {
                    try? realm.safeWrite {
                        file.isAvailableOffline = false
                    }
                    completion(error)
                }
            } else {
                let safeFile = file.freeze()
                var token: ObservationToken?
                token = DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { _, error in
                    token?.cancel()
                    if error != nil && error != .taskRescheduled {
                        // Mark it as not available offline
                        self.updateFileProperty(fileId: safeFile.id) { file in
                            file.isAvailableOffline = false
                        }
                    }
                    self.notifyObserversWith(file: safeFile)
                    Task { @MainActor in
                        completion(error)
                    }
                }
                DownloadQueue.instance.addToQueue(file: file, userId: drive.userId)
            }
        } else {
            try? realm.safeWrite {
                file.isAvailableOffline = false
            }
            // Cancel the download
            DownloadQueue.instance.operation(for: file.id)?.cancel()
            try? fileManager.createDirectory(at: file.localContainerUrl, withIntermediateDirectories: true)
            try? fileManager.moveItem(at: oldUrl, to: file.localUrl)
            notifyObserversWith(file: file)
            try? fileManager.removeItem(at: oldUrl)
            completion(nil)
        }
    }

    public func setFileShareLink(file: ProxyFile, shareLink: ShareLink?) {
        updateFileProperty(fileId: file.id) { file in
            file.sharelink = shareLink
            file.capabilities.canBecomeSharelink = shareLink == nil
        }
    }

    public func setFileDropBox(file: ProxyFile, dropBox: DropBox?) {
        updateFileProperty(fileId: file.id) { file in
            file.dropbox = dropBox
            file.capabilities.canBecomeDropbox = dropBox == nil
        }
    }

    public func getLocalRecentActivities() -> [FileActivity] {
        return Array(getRealm().objects(FileActivity.self).sorted(by: \.createdAt, ascending: false).freeze())
    }

    public func setLocalRecentActivities(_ activities: [FileActivity]) {
        backgroundQueue.async { [self] in
            let realm = getRealm()
            let homeRootFile = DriveFileManager.homeRootFile
            var activitiesSafe = [FileActivity]()
            for activity in activities {
                guard !activity.isInvalidated else {
                    continue
                }

                let safeActivity = FileActivity(value: activity)
                if let file = activity.file {
                    let safeFile = file.detached()
                    keepCacheAttributesForFile(newFile: safeFile, keepProperties: .all, using: realm)
                    homeRootFile.children.insert(safeFile)
                    safeActivity.file = safeFile
                }
                activitiesSafe.append(safeActivity)
            }

            try? realm.safeWrite {
                realm.delete(realm.objects(FileActivity.self))
                realm.add(activitiesSafe, update: .modified)
                realm.add(homeRootFile, update: .modified)
            }
            deleteOrphanFiles(root: DriveFileManager.homeRootFile, newFiles: Array(homeRootFile.children), using: realm)
        }
    }

    public func setLocalFiles(_ files: [File], root: File, deleteOrphans: Bool) {
        let realm = getRealm()
        for file in files {
            keepCacheAttributesForFile(newFile: file, keepProperties: [.standard, .extras], using: realm)
            root.children.insert(file)
            file.capabilities = Rights(value: file.capabilities)
        }

        try? realm.safeWrite {
            realm.add(root, update: .modified)
        }
        if deleteOrphans {
            deleteOrphanFiles(root: root, newFiles: files, using: realm)
        }
    }

    public func lastModifiedFiles(page: Int = 1) async throws -> (files: [File], moreComing: Bool) {
        do {
            let files = try await apiFetcher.lastModifiedFiles(drive: drive, page: page)

            setLocalFiles(files, root: DriveFileManager.lastModificationsRootFile, deleteOrphans: page == 1)
            return (files.map { $0.freeze() }, files.count == Endpoint.itemsPerPage)
        } catch {
            if let files = getCachedFile(id: DriveFileManager.lastModificationsRootFile.id, freeze: true)?.children {
                return (Array(files), false)
            } else {
                throw error
            }
        }
    }

    public func lastPictures(page: Int = 1) async throws -> (files: [File], moreComing: Bool) {
        do {
            let files = try await apiFetcher.searchFiles(
                drive: drive,
                fileTypes: [.image, .video],
                categories: [],
                belongToAllCategories: false,
                page: page,
                sortType: .newer
            )

            setLocalFiles(files, root: DriveFileManager.lastPicturesRootFile, deleteOrphans: page == 1)
            return (files.map { $0.freeze() }, files.count == Endpoint.itemsPerPage)
        } catch {
            if let files = getCachedFile(id: DriveFileManager.lastPicturesRootFile.id, freeze: true)?.children {
                return (Array(files), false)
            } else {
                throw error
            }
        }
    }

    public struct ActivitiesResult {
        public var inserted: [File]
        public var updated: [File]
        public var deleted: [File]

        public init(inserted: [File] = [], updated: [File] = [], deleted: [File] = []) {
            self.inserted = inserted
            self.updated = updated
            self.deleted = deleted
        }
    }

    public func fileActivities(file: ProxyFile,
                               from timestamp: Int? = nil) async throws -> (result: ActivitiesResult, responseAt: Int) {
        // Get all pages and assemble
        let realm = getRealm()
        realm.refresh()
        let timestamp = try TimeInterval(timestamp ?? file.resolve(using: realm).responseAt)
        var page = 1
        var moreComing = true
        var pagedActions = [Int: FileActivityType]()
        var pagedActivities = ActivitiesResult()
        var responseAt = 0
        while moreComing {
            // Get activities page
            let (activities, pageResponseAt) = try await apiFetcher.fileActivities(
                file: file,
                from: Date(timeIntervalSince1970: timestamp),
                page: page
            )
            moreComing = activities.count == Endpoint.itemsPerPage
            page += 1
            responseAt = pageResponseAt ?? Int(Date().timeIntervalSince1970)
            // Get file from Realm
            let realm = getRealm()
            let cachedFile = try file.resolve(using: realm)
            // Apply activities to file
            let results = apply(
                activities: activities,
                to: cachedFile,
                pagedActions: &pagedActions,
                timestamp: responseAt,
                using: realm
            )
            pagedActivities.inserted.insert(contentsOf: results.inserted, at: 0)
            pagedActivities.updated.insert(contentsOf: results.updated, at: 0)
            pagedActivities.deleted.insert(contentsOf: results.deleted, at: 0)
        }
        return (pagedActivities, responseAt)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func apply(activities: [FileActivity],
                       to file: File,
                       pagedActions: inout [Int: FileActivityType],
                       timestamp: Int,
                       using realm: Realm? = nil) -> ActivitiesResult {
        var insertedFiles = [File]()
        var updatedFiles = [File]()
        var deletedFiles = [File]()
        let realm = realm ?? getRealm()
        realm.refresh()
        realm.beginWrite()
        for activity in activities {
            let fileId = activity.fileId
            if pagedActions[fileId] == nil {
                switch activity.action {
                case .fileDelete, .fileTrash:
                    if let file = realm.object(ofType: File.self, forPrimaryKey: fileId), !file.isInvalidated {
                        deletedFiles.append(file.freeze())
                    }
                    removeFileInDatabase(fileId: fileId, cascade: true, withTransaction: false, using: realm)
                    if let file = activity.file {
                        deletedFiles.append(file)
                    }
                    pagedActions[fileId] = .fileDelete
                case .fileMoveOut:
                    if let file = realm.object(ofType: File.self, forPrimaryKey: fileId),
                       !file.isInvalidated,
                       let oldParent = file.parent {
                        oldParent.children.remove(file)
                    }
                    if let file = activity.file {
                        deletedFiles.append(file)
                    }
                    pagedActions[fileId] = .fileDelete
                case .fileRename:
                    if let oldFile = realm.object(ofType: File.self, forPrimaryKey: fileId),
                       !file.isInvalidated,
                       let renamedFile = activity.file {
                        try? renameCachedFile(updatedFile: renamedFile, oldFile: oldFile)
                        // If the file is a folder we have to copy the old attributes which are not returned by the API
                        keepCacheAttributesForFile(newFile: renamedFile, keepProperties: [.standard, .extras], using: realm)
                        realm.add(renamedFile, update: .modified)
                        file.children.insert(renamedFile)
                        renamedFile.applyLastModifiedDateToLocalFile()
                        updatedFiles.append(renamedFile)
                        pagedActions[fileId] = .fileUpdate
                    }
                case .fileMoveIn, .fileRestore, .fileCreate:
                    if let newFile = activity.file {
                        keepCacheAttributesForFile(newFile: newFile, keepProperties: [.standard, .extras], using: realm)
                        realm.add(newFile, update: .modified)
                        // If was already had a local parent, remove it
                        if let file = realm.object(ofType: File.self, forPrimaryKey: fileId),
                           !file.isInvalidated,
                           let oldParent = file.parent {
                            oldParent.children.remove(file)
                        }
                        file.children.insert(newFile)
                        insertedFiles.append(newFile)
                        pagedActions[fileId] = .fileCreate
                    }
                case .fileFavoriteCreate, .fileFavoriteRemove, .fileUpdate, .fileShareCreate, .fileShareUpdate, .fileShareDelete,
                     .collaborativeFolderCreate, .collaborativeFolderUpdate, .collaborativeFolderDelete, .fileColorUpdate,
                     .fileColorDelete:
                    if let newFile = activity.file {
                        if newFile.isTrashed {
                            removeFileInDatabase(fileId: fileId, cascade: true, withTransaction: false, using: realm)
                            deletedFiles.append(newFile)
                            pagedActions[fileId] = .fileDelete
                        } else {
                            keepCacheAttributesForFile(newFile: newFile, keepProperties: [.standard, .extras], using: realm)
                            realm.add(newFile, update: .modified)
                            file.children.insert(newFile)
                            updatedFiles.append(newFile)
                            pagedActions[fileId] = .fileUpdate
                        }
                    }
                default:
                    break
                }
            }
        }
        file.responseAt = timestamp
        try? realm.commitWrite()
        return ActivitiesResult(
            inserted: insertedFiles.map { $0.freeze() },
            updated: updatedFiles.map { $0.freeze() },
            deleted: deletedFiles
        )
    }

    public func filesActivities(files: [File], from date: Date) async throws -> [ActivitiesForFile] {
        let (result, responseAt) = try await apiFetcher
            .filesActivities(drive: drive, files: files.map { $0.proxify() }, from: date)
        // Update last sync date
        if let responseAt {
            UserDefaults.shared.lastSyncDateOfflineFiles = responseAt
        }
        return result
    }

    public func updateAvailableOfflineFiles() async throws {
        let offlineFiles = getAvailableOfflineFiles()
        guard !offlineFiles.isEmpty else { return }
        let date = Date(timeIntervalSince1970: TimeInterval(UserDefaults.shared.lastSyncDateOfflineFiles))
        // Get activities
        let filesActivities = try await filesActivities(files: offlineFiles, from: date)
        for activities in filesActivities {
            guard let file = offlineFiles.first(where: { $0.id == activities.id }) else {
                continue
            }

            if activities.result {
                try applyActivities(activities, offlineFile: file)
            } else if let message = activities.message {
                handleError(message: message, offlineFile: file)
            }
        }
    }

    private func applyActivities(_ activities: ActivitiesForFile, offlineFile file: File) throws {
        // Update file in Realm & rename if needed
        if let newFile = activities.file {
            let realm = getRealm()
            keepCacheAttributesForFile(newFile: newFile, keepProperties: [.standard, .extras], using: realm)
            _ = try updateFileInDatabase(updatedFile: newFile, oldFile: file, using: realm)
        }
        // Apply activities to file
        var handledActivities = Set<FileActivityType>()
        for activity in activities.activities where activity.action != nil && !handledActivities.contains(activity.action!) {
            if activity.action == .fileUpdate {
                // Download new version
                DownloadQueue.instance.addToQueue(file: file, userId: drive.userId)
            }
            handledActivities.insert(activity.action!)
        }
    }

    private func handleError(message: String, offlineFile file: File) {
        if message == DriveError.objectNotFound.code {
            // File has been deleted -- remove it from offline files
            setFileAvailableOffline(file: file, available: false) { _ in
                // No need to wait for the response, no error will be returned
            }
        } else {
            SentryDebug.capture(message: message)
        }
        // Silently handle error
        DDLogError("Error while fetching [\(file.id) - \(file.name)] in [\(drive.id) - \(drive.name)]: \(message)")
    }

    public func getWorkingSet() -> [File] {
        // let predicate = NSPredicate(format: "isFavorite = %d OR lastModifiedAt >= %d", true, Int(Date(timeIntervalSinceNow:
        // -3600).timeIntervalSince1970))
        let files = getRealm().objects(File.self).sorted(by: \.lastModifiedAt, ascending: false)
        var result = [File]()
        for i in 0 ..< min(20, files.count) {
            result.append(files[i])
        }
        return result
    }

    public func add(category: Category, to file: ProxyFile) async throws {
        let categoryId = category.id
        let response = try await apiFetcher.add(category: category, to: file)
        if response.result {
            updateFileProperty(fileId: file.id) { file in
                let newCategory = FileCategory(categoryId: categoryId, userId: self.drive.userId)
                file.categories.append(newCategory)
            }
        }
    }

    public func add(category: Category, to files: [ProxyFile]) async throws {
        let categoryId = category.id
        let response = try await apiFetcher.add(drive: drive, category: category, to: files)
        for fileResponse in response where fileResponse.result {
            updateFileProperty(fileId: fileResponse.id) { file in
                let newCategory = FileCategory(categoryId: categoryId, userId: self.drive.userId)
                file.categories.append(newCategory)
            }
        }
    }

    public func remove(category: Category, from file: ProxyFile) async throws {
        let categoryId = category.id
        let response = try await apiFetcher.remove(category: category, from: file)
        if response {
            updateFileProperty(fileId: file.id) { file in
                if let index = file.categories.firstIndex(where: { $0.categoryId == categoryId }) {
                    file.categories.remove(at: index)
                }
            }
        }
    }

    public func remove(category: Category, from files: [ProxyFile]) async throws {
        let categoryId = category.id
        let response = try await apiFetcher.remove(drive: drive, category: category, from: files)
        for fileResponse in response where fileResponse.result {
            updateFileProperty(fileId: fileResponse.id) { file in
                if let index = file.categories.firstIndex(where: { $0.categoryId == categoryId }) {
                    file.categories.remove(at: index)
                }
            }
        }
    }

    public func createCategory(name: String, color: String) async throws -> Category {
        let category = try await apiFetcher.createCategory(drive: drive, name: name, color: color)
        // Add category to drive
        let realm = DriveInfosManager.instance.getRealm()
        let drive = DriveInfosManager.instance.getDrive(objectId: drive.objectId, freeze: false, using: realm)
        try? realm.write {
            drive?.categories.append(category)
        }
        if let drive {
            self.drive = drive.freeze()
        }
        return category.freeze()
    }

    public func edit(category: Category, name: String?, color: String) async throws -> Category {
        let categoryId = category.id
        let category = try await apiFetcher.editCategory(drive: drive, category: category, name: name, color: color)
        // Update category on drive
        let realm = DriveInfosManager.instance.getRealm()
        if let drive = DriveInfosManager.instance.getDrive(objectId: drive.objectId, freeze: false, using: realm) {
            try? realm.write {
                if let index = drive.categories.firstIndex(where: { $0.id == categoryId }) {
                    drive.categories[index] = category
                }
            }
            self.drive = drive.freeze()
        }
        return category
    }

    public func delete(category: Category) async throws -> Bool {
        let categoryId = category.id
        let response = try await apiFetcher.deleteCategory(drive: drive, category: category)
        if response {
            // Delete category from drive
            let realmDrive = DriveInfosManager.instance.getRealm()
            if let drive = DriveInfosManager.instance.getDrive(objectId: drive.objectId, freeze: false, using: realmDrive) {
                try? realmDrive.write {
                    if let index = drive.categories.firstIndex(where: { $0.id == categoryId }) {
                        drive.categories.remove(at: index)
                    }
                }
                self.drive = drive.freeze()
            }
            // Delete category from files
            let realm = getRealm()
            for file in realm.objects(File.self).filter(NSPredicate(format: "ANY categories.categoryId = %d", categoryId)) {
                try? realm.write {
                    realm.delete(file.categories.filter("categoryId = %d", categoryId))
                }
            }
        }
        return response
    }

    public func setFavorite(file: ProxyFile, favorite: Bool) async throws {
        var response: Bool
        if favorite {
            response = try await apiFetcher.favorite(file: file)
        } else {
            response = try await apiFetcher.unfavorite(file: file)
        }
        if response {
            updateFileProperty(fileId: file.id) { file in
                file.isFavorite = favorite
            }
        }
    }

    public func delete(file: ProxyFile) async throws -> CancelableResponse {
        let response = try await apiFetcher.delete(file: file)
        backgroundQueue.async { [self] in
            let localRealm = getRealm()
            let savedFile = try? file.resolve(using: localRealm).freeze()
            removeFileInDatabase(fileId: file.id, cascade: true, withTransaction: true, using: localRealm)
            if let file = savedFile {
                savedFile?.signalChanges(userId: drive.userId)
                notifyObserversWith(file: file)
            }
            deleteOrphanFiles(
                root: DriveFileManager.homeRootFile,
                DriveFileManager.lastPicturesRootFile,
                DriveFileManager.lastModificationsRootFile,
                DriveFileManager.searchFilesRootFile,
                using: localRealm
            )
        }
        return response
    }

    public func move(file: ProxyFile, to destination: ProxyFile) async throws -> (CancelableResponse, File) {
        let response = try await apiFetcher.move(file: file, to: destination)
        // Add the moved file to Realm
        let realm = getRealm()
        let newParent = try destination.resolve(using: realm)
        let file = try file.resolve(using: realm)

        let oldParent = file.parent
        try? realm.write {
            oldParent?.children.remove(file)
            newParent.children.insert(file)
        }
        if let oldParent {
            oldParent.signalChanges(userId: drive.userId)
            notifyObserversWith(file: oldParent)
        }
        newParent.signalChanges(userId: drive.userId)
        notifyObserversWith(file: newParent)
        return (response, file)
    }

    public func rename(file: ProxyFile, newName: String) async throws -> File {
        _ = try await apiFetcher.rename(file: file, newName: newName)
        let realm = getRealm()
        let file = try file.resolve(using: realm)
        let newFile = file.detached()
        newFile.name = newName
        _ = try updateFileInDatabase(updatedFile: newFile, oldFile: file, using: realm)
        newFile.signalChanges(userId: drive.userId)
        notifyObserversWith(file: newFile)
        return file
    }

    public func duplicate(file: ProxyFile, duplicateName: String) async throws -> File {
        let duplicatedFile = try await apiFetcher.duplicate(file: file, duplicateName: duplicateName)
        let realm = getRealm()
        let duplicateFile = try updateFileInDatabase(updatedFile: duplicatedFile, using: realm)
        let parent = try file.resolve(using: realm).parent
        try realm.safeWrite {
            parent?.children.insert(duplicateFile)
        }

        duplicateFile.signalChanges(userId: drive.userId)
        if let parent = duplicatedFile.parent {
            parent.signalChanges(userId: drive.userId)
            notifyObserversWith(file: parent)
        }
        return duplicateFile
    }

    public func createDirectory(in parentDirectory: ProxyFile, name: String, onlyForMe: Bool) async throws -> File {
        let directory = try await apiFetcher.createDirectory(in: parentDirectory, name: name, onlyForMe: onlyForMe)
        let realm = getRealm()
        let createdDirectory = try updateFileInDatabase(updatedFile: directory, using: realm)
        // Add directory to parent
        let parent = try? parentDirectory.resolve(using: realm)
        try realm.safeWrite {
            parent?.children.insert(createdDirectory)
        }
        if let parent = createdDirectory.parent {
            parent.signalChanges(userId: drive.userId)
            notifyObserversWith(file: parent)
        }
        return createdDirectory.freeze()
    }

    public func createCommonDirectory(name: String, forAllUser: Bool) async throws -> File {
        let directory = try await apiFetcher.createCommonDirectory(drive: drive, name: name, forAllUser: forAllUser)
        let createdDirectory = try updateFileInDatabase(updatedFile: directory)
        if let parent = createdDirectory.parent {
            parent.signalChanges(userId: drive.userId)
            notifyObserversWith(file: parent)
        }
        return createdDirectory.freeze()
    }

    public func createDropBox(parentDirectory: ProxyFile, name: String, onlyForMe: Bool,
                              settings: DropBoxSettings) async throws -> File {
        // Create directory
        let createdDirectory = try await apiFetcher.createDirectory(in: parentDirectory, name: name, onlyForMe: onlyForMe)
        // Set up dropbox
        let dropbox = try await apiFetcher.createDropBox(directory: createdDirectory.proxify(), settings: settings)
        let realm = getRealm()
        let directory = try updateFileInDatabase(updatedFile: createdDirectory, using: realm)

        let parent = try? parentDirectory.resolve(using: realm)
        try realm.write {
            directory.dropbox = dropbox
            parent?.children.insert(directory)
        }
        if let parent = directory.parent {
            parent.signalChanges(userId: drive.userId)
            notifyObserversWith(file: parent)
        }
        return directory.freeze()
    }

    public func updateDropBox(directory: ProxyFile, settings: DropBoxSettings) async throws -> Bool {
        let response = try await apiFetcher.updateDropBox(directory: directory, settings: settings)
        if response {
            // Update dropbox in Realm
            let dropbox = try await apiFetcher.getDropBox(directory: directory)
            setFileDropBox(file: directory, dropBox: dropbox)
        }
        return response
    }

    public func createFile(in parentDirectory: ProxyFile, name: String, type: String) async throws -> File {
        let file = try await apiFetcher.createFile(in: parentDirectory, name: name, type: type)
        let realm = getRealm()
        let createdFile = try updateFileInDatabase(updatedFile: file, using: realm)
        // Add file to parent
        let parent = try? parentDirectory.resolve(using: realm)
        try realm.write {
            parent?.children.insert(createdFile)
        }
        createdFile.signalChanges(userId: drive.userId)

        if let parent = createdFile.parent {
            parent.signalChanges(userId: drive.userId)
            notifyObserversWith(file: parent)
        }

        return createdFile.freeze()
    }

    @discardableResult
    public func createOrRemoveShareLink(for file: ProxyFile, right: ShareLinkPermission) async throws -> ShareLink? {
        if right == .restricted {
            // Remove share link
            let response = try await removeShareLink(for: file)
            if response {
                return nil
            } else {
                throw DriveError.serverError
            }
        } else {
            // Update share link
            let shareLink = try await createShareLink(for: file)
            return shareLink
        }
    }

    public func createShareLink(for file: ProxyFile) async throws -> ShareLink {
        let shareLink = try await apiFetcher.createShareLink(for: file, isFreeDrive: drive.isFreePack)
        // Fix for API not returning share link activities
        setFileShareLink(file: file, shareLink: shareLink)
        return shareLink.freeze()
    }

    public func updateShareLink(for file: ProxyFile, settings: ShareLinkSettings) async throws -> Bool {
        let response = try await apiFetcher.updateShareLink(for: file, settings: settings)
        if response {
            // Update sharelink in Realm
            let shareLink = try await apiFetcher.shareLink(for: file)
            setFileShareLink(file: file, shareLink: shareLink)
        }
        return response
    }

    public func removeShareLink(for file: ProxyFile) async throws -> Bool {
        let response = try await apiFetcher.removeShareLink(for: file)
        if response {
            // Fix for API not returning share link activities
            setFileShareLink(file: file, shareLink: nil)
        }
        return response
    }

    func updateExternalImport(id: Int, action: ExternalImportAction) {
        let realm = getRealm()
        guard let file = realm.objects(File.self).where({ $0.externalImport.id == id }).first else {
            // No file corresponding to external import, ignore it
            return
        }

        switch action {
        case .importFinish:
            try? realm.write {
                file.externalImport?.status = .done
            }
        case .cancel:
            try? realm.write {
                file.externalImport?.status = .failed
            }
        default:
            break
        }
    }

    // MARK: - Utilities

    public func getLocalSortedDirectoryFiles(directory: File, sortType: SortType) -> [File] {
        let children = directory.children.sorted(by: [
            SortDescriptor(keyPath: \File.type, ascending: true),
            SortDescriptor(keyPath: \File.visibility, ascending: false),
            sortType.value.sortDescriptor
        ])

        return Array(children.freeze())
    }

    private func removeFileInDatabase(fileId: Int, cascade: Bool, withTransaction: Bool, using realm: Realm? = nil) {
        let realm = realm ?? getRealm()
        realm.refresh()

        if let file = realm.object(ofType: File.self, forPrimaryKey: fileId), !file.isInvalidated {
            if fileManager.fileExists(atPath: file.localContainerUrl.path) {
                try? fileManager.removeItem(at: file.localContainerUrl) // Check that it was correctly removed?
            }

            if cascade {
                for child in file.children.freeze() where !child.isInvalidated {
                    removeFileInDatabase(fileId: child.id, cascade: cascade, withTransaction: withTransaction, using: realm)
                }
            }
            if withTransaction {
                try? realm.safeWrite {
                    realm.delete(file)
                }
            } else {
                realm.delete(file)
            }
        }
    }

    private func deleteOrphanFiles(root: File..., newFiles: [File]? = nil, using realm: Realm? = nil) {
        let realm = realm ?? getRealm()
        realm.refresh()

        let maybeOrphanFiles = realm.objects(File.self).filter("parentLink.@count == 1")
            .filter(NSPredicate(format: "ANY parentLink.id IN %@", root.map(\.id)))
        var orphanFiles = [File]()

        for maybeOrphanFile in maybeOrphanFiles {
            if newFiles == nil || !(newFiles ?? []).contains(maybeOrphanFile) {
                if fileManager.fileExists(atPath: maybeOrphanFile.localContainerUrl.path) {
                    try? fileManager.removeItem(at: maybeOrphanFile.localContainerUrl) // Check that it was correctly removed?
                }
                orphanFiles.append(maybeOrphanFile)
            }
        }

        try? realm.safeWrite {
            realm.delete(orphanFiles)
        }
    }

    private func updateFileProperty(fileId: Int, using realm: Realm? = nil, _ block: (File) -> Void) {
        let realm = realm ?? getRealm()
        realm.refresh()

        if let file = realm.object(ofType: File.self, forPrimaryKey: fileId), !file.isInvalidated {
            try? realm.write {
                block(file)
            }
            notifyObserversWith(file: file)
        }
    }

    private func updateFileInDatabase(updatedFile: File, oldFile: File? = nil, using realm: Realm? = nil) throws -> File {
        let realm = realm ?? getRealm()
        realm.refresh()

        // rename file if it was renamed in the drive
        if let oldFile {
            try renameCachedFile(updatedFile: updatedFile, oldFile: oldFile)
        }

        try realm.write {
            realm.add(updatedFile, update: .modified)
        }
        return updatedFile
    }

    public func renameCachedFile(updatedFile: File, oldFile: File) throws {
        if updatedFile.name != oldFile.name && fileManager.fileExists(atPath: oldFile.localUrl.path) {
            try fileManager.moveItem(atPath: oldFile.localUrl.path, toPath: updatedFile.localUrl.path)
        }
    }

    struct FilePropertiesOptions: OptionSet {
        let rawValue: Int

        static let fullyDownloaded = FilePropertiesOptions(rawValue: 1 << 0)
        static let children = FilePropertiesOptions(rawValue: 1 << 1)
        static let responseAt = FilePropertiesOptions(rawValue: 1 << 2)
        static let path = FilePropertiesOptions(rawValue: 1 << 3)
        static let users = FilePropertiesOptions(rawValue: 1 << 4)
        static let version = FilePropertiesOptions(rawValue: 1 << 5)
        static let capabilities = FilePropertiesOptions(rawValue: 1 << 6)

        static let standard: FilePropertiesOptions = [.fullyDownloaded, .children, .responseAt]
        static let extras: FilePropertiesOptions = [.path, .users, .version]
        static let all: FilePropertiesOptions = [.fullyDownloaded, .children, .responseAt, .path, .users, .version, .capabilities]
    }

    private func keepCacheAttributesForFile(newFile: File, keepProperties: FilePropertiesOptions, using realm: Realm? = nil) {
        let realm = realm ?? getRealm()
        realm.refresh()

        guard let savedChild = realm.object(ofType: File.self, forPrimaryKey: newFile.id),
              !savedChild.isInvalidated else { return }
        newFile.isAvailableOffline = savedChild.isAvailableOffline
        newFile.versionCode = savedChild.versionCode
        if keepProperties.contains(.fullyDownloaded) {
            newFile.fullyDownloaded = savedChild.fullyDownloaded
        }
        if keepProperties.contains(.children) {
            newFile.children = savedChild.children
        }
        if keepProperties.contains(.responseAt) {
            newFile.responseAt = savedChild.responseAt
        }
        if keepProperties.contains(.path) {
            newFile.path = savedChild.path
        }
        if keepProperties.contains(.users) {
            newFile.users = savedChild.users.freeze()
        }
        if keepProperties.contains(.version), let version = savedChild.version {
            newFile.version = FileVersion(value: version)
        }
        if keepProperties.contains(.capabilities) {
            newFile.capabilities = Rights(value: savedChild.capabilities)
        }
    }

    /**
     Get a live version for the given file (if the file is not cached in realm it is added and then returned)
     - Returns: A realm managed file
     */
    public func getManagedFile(from file: File, using realm: Realm? = nil) -> File {
        let realm = realm ?? getRealm()
        realm.refresh()

        if let cachedFile = getCachedFile(id: file.id, freeze: false, using: realm) {
            return cachedFile
        } else {
            keepCacheAttributesForFile(newFile: file, keepProperties: [.all], using: realm)
            try? realm.write {
                realm.add(file, update: .all)
            }
            return file
        }
    }

    public func undoAction(cancelId: String) async throws {
        try await apiFetcher.undoAction(drive: drive, cancelId: cancelId)
    }

    public func updateColor(directory: File, color: String) async throws -> Bool {
        let fileId = directory.id
        let result = try await apiFetcher.updateColor(directory: directory.proxify(), color: color)
        if result {
            updateFileProperty(fileId: fileId) { file in
                file.color = color
            }
        }
        return result
    }
}

public extension Realm {
    func safeWrite(_ block: () throws -> Void) throws {
        if isInWriteTransaction {
            try block()
        } else {
            try write(block)
        }
    }
}

// MARK: - Observation

public extension DriveFileManager {
    typealias FileId = Int

    @discardableResult
    func observeFileUpdated<T: AnyObject>(_ observer: T, fileId: FileId?, using closure: @escaping (File) -> Void)
        -> ObservationToken {
        let key = UUID()
        didUpdateFileObservers[key] = { [weak self, weak observer] updatedDirectory in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.didUpdateFileObservers.removeValue(forKey: key)
                return
            }

            if fileId == nil || fileId == updatedDirectory.id {
                closure(updatedDirectory)
            }
        }

        return ObservationToken { [weak self] in
            self?.didUpdateFileObservers.removeValue(forKey: key)
        }
    }

    func notifyObserversWith(file: File) {
        let file = file.freezeIfNeeded()
        for observer in didUpdateFileObservers.values {
            observer(file)
        }
    }
}
