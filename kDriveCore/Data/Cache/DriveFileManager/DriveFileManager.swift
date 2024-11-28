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
import InfomaniakCoreDB
import InfomaniakDI
import InfomaniakLogin
import RealmSwift
import SwiftRegex

// TODO: Move to core
extension TransactionExecutor: CustomStringConvertible {
    public var description: String {
        var render = "TransactionExecutor: realm access issue"
        try? writeTransaction { realm in
            render = """
            TransactionExecutor:
            realmURL:\(realm.configuration.fileURL)
            inMemory:\(realm.configuration.inMemoryIdentifier)
            """
        }
        return render
    }
}

// MARK: - Transactionable

public final class DriveFileManager {
    @LazyInjectService var driveInfosManager: DriveInfosManager

    public static let constants = DriveFileManagerConstants()

    private let fileManager = FileManager.default
    public static var favoriteRootFile: File {
        return File(id: -1, name: "Favorite")
    }

    public static var trashRootFile: File {
        return File(id: -2, name: "Trash")
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

    public static var sharedWithMeRootFile: File {
        // We can't migrate fake roots. Previous sharedWithMeRootFile.id was -3
        return File(id: -10, name: "Shared with me", visibility: .isSharedSpace)
    }

    public let realmConfiguration: Realm.Configuration

    // TODO: Fetch a drive with a computed property instead of tracking a Realm object
    public private(set) var drive: Drive

    public let apiFetcher: DriveApiFetcher

    private var didUpdateFileObservers = [UUID: (File) -> Void]()

    /// Fetch and write into DB with this object
    public let database: Transactionable

    /// Context this object was initialized with
    public let context: DriveFileManagerContext

    /// Build a realm configuration for a specific Drive
    public static func configuration(context: DriveFileManagerContext, driveId: Int, driveUserId: Int) -> Realm.Configuration {
        let realmURL = context.realmURL(driveId: driveId, driveUserId: driveUserId)

        let inMemoryIdentifier: String?
        if case .publicShare(let identifier) = context {
            inMemoryIdentifier = "inMemory:\(identifier)"
        } else {
            inMemoryIdentifier = nil
        }

        return Realm.Configuration(
            fileURL: realmURL,
            inMemoryIdentifier: inMemoryIdentifier,
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
                if oldSchemaVersion < 10 {
                    migration.enumerateObjects(ofType: File.className()) { oldObject, newObject in
                        if let id = oldObject?["id"] as? Int,
                           let driveId = oldObject?["driveId"] as? Int {
                            newObject?["uid"] = File.uid(driveId: driveId, fileId: id)
                            newObject?["revisedAt"] = Date(timeIntervalSince1970: 0)
                        } else if let oldObject {
                            migration.delete(oldObject)
                        } else if let newObject {
                            migration.delete(newObject)
                        }
                    }
                }
                if oldSchemaVersion < 12 {
                    migration.enumerateObjects(ofType: Rights.className()) { _, newObject in
                        newObject?["canColor"] = false
                    }
                }
            },
            objectTypes: DriveFileManager.constants.driveObjectTypes
        )
    }

    public var isPublicShare: Bool {
        switch context {
        case .publicShare:
            return true
        default:
            return false
        }
    }

    public var publicShareProxy: PublicShareProxy? {
        switch context {
        case .publicShare(let shareProxy):
            return shareProxy
        default:
            return nil
        }
    }

    init(drive: Drive, apiFetcher: DriveApiFetcher, context: DriveFileManagerContext = .drive) {
        self.drive = drive
        self.apiFetcher = apiFetcher
        self.context = context
        realmConfiguration = Self.configuration(context: context, driveId: drive.id, driveUserId: drive.userId)

        let realmURL = context.realmURL(driveId: drive.id, driveUserId: drive.userId)
        let realmAccessor = RealmAccessor(realmURL: realmURL, realmConfiguration: realmConfiguration, excludeFromBackup: true)
        database = TransactionExecutor(realmAccessible: realmAccessor)

        // Init root file
        try? database.writeTransaction { writableRealm in
            if getCachedFile(id: DriveFileManager.constants.rootID, freeze: false, using: writableRealm) == nil {
                let rootFile = getCachedRootFile(writableRealm: writableRealm)
                writableRealm.add(rootFile)
            }
        }
    }

    public func instanceWith(context: DriveFileManagerContext) -> DriveFileManager {
        return DriveFileManager(drive: drive, apiFetcher: apiFetcher, context: context)
    }

    /// Delete all drive data cache for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - driveId: Drive ID (`nil` if all user drives)
    public static func deleteUserDriveFiles(userId: Int, driveId: Int? = nil) {
        let files = (try? FileManager.default
            .contentsOfDirectory(at: DriveFileManager.constants.realmRootURL, includingPropertiesForKeys: nil))
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

    public func initRoot() async throws {
        let root = ProxyFile(driveId: drive.id, id: DriveFileManager.constants.rootID)
        _ = try await files(in: root, forceRefresh: true)
    }

    public func files(in directory: ProxyFile, cursor: String? = nil, sortType: SortType = .nameAZ,
                      forceRefresh: Bool = false) async throws -> (files: [File], nextCursor: String?) {
        let fetchFiles: () async throws -> ValidServerResponse<[File]>
        if directory.isRoot {
            fetchFiles = {
                return try await self.apiFetcher.rootFiles(drive: self.drive, cursor: cursor, sortType: sortType)
            }
        } else {
            fetchFiles = {
                return try await self.apiFetcher.files(in: directory, cursor: cursor, sortType: sortType)
            }
        }
        return try await files(in: directory,
                               fetchFiles: fetchFiles,
                               cursor: cursor,
                               sortType: sortType,
                               keepProperties: [.standard, .extras],
                               forceRefresh: forceRefresh)
    }

    private func remoteFiles(in directory: ProxyFile,
                             fetchFiles: () async throws -> ValidServerResponse<[File]>,
                             isInitialCursor: Bool,
                             sortType: SortType,
                             keepProperties: FilePropertiesOptions) async throws -> (files: [File], nextCursor: String?) {
        // Get children from API
        let response = try await fetchFiles()
        let children = response.validApiResponse.data

        var fetchedFiles: [File] = []

        // Keep cached properties for children
        try database.writeTransaction { writableRealm in
            for child in children {
                keepCacheAttributesForFile(newFile: child, keepProperties: keepProperties, writableRealm: writableRealm)
            }

            let managedParent = try directory.resolve(using: writableRealm)
            try writeChildrenToParent(
                children,
                liveParent: managedParent,
                responseAt: response.validApiResponse.responseAt,
                isInitialCursor: isInitialCursor,
                writableRealm: writableRealm
            )

            fetchedFiles = getLocalSortedDirectoryFiles(directory: managedParent, sortType: sortType)
        }

        let nextCursor = response.validApiResponse.hasMore ? response.validApiResponse.cursor : nil

        return (fetchedFiles, nextCursor)
    }

    private func files(in directory: ProxyFile,
                       fetchFiles: () async throws -> ValidServerResponse<[File]>,
                       cursor: String?,
                       sortType: SortType,
                       keepProperties: FilePropertiesOptions,
                       forceRefresh: Bool) async throws -> (files: [File], nextCursor: String?) {
        if let cachedParent = getCachedFile(id: directory.id, freeze: false),
           // We have cache and we show it before fetching activities OR we are not connected to internet and we show what we have
           // anyway
           (cachedParent.canLoadChildrenFromCache && !forceRefresh) || ReachabilityListener.instance.currentStatus == .offline {
            return (getLocalSortedDirectoryFiles(directory: cachedParent, sortType: sortType), nil)
        } else {
            return try await remoteFiles(
                in: directory,
                fetchFiles: fetchFiles,
                isInitialCursor: cursor == nil,
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
            let response = try await apiFetcher.fileInfo(ProxyFile(driveId: drive.id, id: id))
            let file = response.validApiResponse.data

            try? database.writeTransaction { writableRealm in
                keepCacheAttributesForFile(newFile: file, keepProperties: [.standard], writableRealm: writableRealm)

                writableRealm.add(file, update: .modified)
            }

            return file.freeze()
        }
    }

    public func favorites(cursor: String? = nil,
                          sortType: SortType = .nameAZ,
                          forceRefresh: Bool = false) async throws -> (files: [File], nextCursor: String?) {
        try await files(in: getManagedFile(from: DriveFileManager.favoriteRootFile).proxify(),
                        fetchFiles: {
                            let favorites = try await apiFetcher.favorites(drive: drive, cursor: cursor, sortType: sortType)
                            return favorites
                        },
                        cursor: cursor,
                        sortType: sortType,
                        keepProperties: [.standard, .extras],
                        forceRefresh: forceRefresh)
    }

    public func mySharedFiles(cursor: String? = nil,
                              sortType: SortType = .nameAZ,
                              forceRefresh: Bool = false) async throws -> (files: [File], nextCursor: String?) {
        try await files(in: getManagedFile(from: DriveFileManager.mySharedRootFile).proxify(),
                        fetchFiles: {
                            let mySharedFiles = try await apiFetcher.mySharedFiles(
                                drive: drive,
                                cursor: cursor,
                                sortType: sortType
                            )
                            return mySharedFiles
                        },
                        cursor: cursor,
                        sortType: sortType,
                        keepProperties: [.standard, .path, .version],
                        forceRefresh: forceRefresh)
    }

    public func sharedWithMeFiles(cursor: String? = nil,
                                  sortType: SortType = .nameAZ,
                                  forceRefresh: Bool = false) async throws -> (files: [File], nextCursor: String?) {
        try await files(in: getManagedFile(from: DriveFileManager.sharedWithMeRootFile).proxify(),
                        fetchFiles: {
                            let mySharedFiles = try await apiFetcher.sharedWithMeFiles(
                                drive: drive,
                                cursor: cursor,
                                sortType: sortType
                            )
                            return mySharedFiles
                        },
                        cursor: cursor,
                        sortType: sortType,
                        keepProperties: [.standard, .path, .version],
                        forceRefresh: forceRefresh)
    }

    public func publicShareFiles(rootProxy: ProxyFile,
                                 publicShareProxy: PublicShareProxy,
                                 cursor: String? = nil,
                                 sortType: SortType = .nameAZ,
                                 forceRefresh: Bool = false,
                                 publicShareApiFetcher: PublicShareApiFetcher) async throws
        -> (files: [File], nextCursor: String?) {
        try await files(in: rootProxy,
                        fetchFiles: {
                            let mySharedFiles = try await publicShareApiFetcher.shareLinkFileChildren(
                                rootFolderId: rootProxy.id,
                                publicShareProxy: publicShareProxy,
                                sortType: sortType
                            )
                            return mySharedFiles
                        },
                        cursor: cursor,
                        sortType: sortType,
                        keepProperties: [.standard, .path, .version],
                        forceRefresh: forceRefresh)
    }

    public func searchFile(query: String? = nil,
                           date: DateInterval? = nil,
                           fileType: ConvertedType? = nil,
                           categories: [Category],
                           fileExtensions: [String],
                           belongToAllCategories: Bool,
                           cursor: String? = nil,
                           sortType: SortType = .nameAZ) async throws -> (files: [File], nextCursor: String?) {
        do {
            return try await remoteFiles(in: getManagedFile(from: DriveFileManager.searchFilesRootFile).proxify(),
                                         fetchFiles: {
                                             let searchResults = try await apiFetcher.searchFiles(
                                                 drive: drive,
                                                 query: query,
                                                 date: date,
                                                 fileTypes: [fileType].compactMap { type in
                                                     guard type != .searchExtension else {
                                                         return nil
                                                     }

                                                     return type
                                                 },
                                                 fileExtensions: fileExtensions,
                                                 categories: categories,
                                                 belongToAllCategories: belongToAllCategories,
                                                 cursor: cursor,
                                                 sortType: sortType
                                             )
                                             return searchResults
                                         },
                                         isInitialCursor: cursor == nil,
                                         sortType: sortType,
                                         keepProperties: [.standard, .extras])
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
                              fileExtensions: [String],
                              belongToAllCategories: Bool,
                              sortType: SortType = .nameAZ) -> Results<File> {
        let results = database.fetchResults(ofType: File.self) { lazyCollection in
            var searchResults = lazyCollection.filter("id > 0")
            if let query, !query.isBlank {
                searchResults = searchResults.filter("name CONTAINS[cd] %@", query)
            }

            if let date {
                searchResults = searchResults.filter(
                    "lastModifiedAt >= %@ && lastModifiedAt <= %@",
                    date.start as NSDate,
                    date.end as NSDate
                )
            }

            if let fileType {
                switch fileType {
                case .folder:
                    searchResults = searchResults.filter("rawType == \"dir\"")
                case .searchExtension:
                    searchResults = searchResults.filter("rawType IN %@", fileExtensions)
                default:
                    searchResults = searchResults.filter("rawType == %@", fileType.rawValue)
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

        return results
    }

    public func setFileShareLink(file: ProxyFile, shareLink: ShareLink?) {
        updateFileProperty(fileUid: file.uid) { file in
            file.sharelink = shareLink
            file.capabilities.canBecomeSharelink = shareLink == nil
        }
    }

    public func setFileDropBox(file: ProxyFile, dropBox: DropBox?) {
        updateFileProperty(fileUid: file.uid) { file in
            file.dropbox = dropBox
            file.capabilities.canBecomeDropbox = dropBox == nil
        }
    }

    public func setLocalFiles(_ files: [File], root: File, deleteOrphans: Bool) {
        guard let liveRoot = root.thaw() else { return }
        try? database.writeTransaction { writableRealm in
            try writeChildrenToParent(
                files,
                liveParent: liveRoot,
                responseAt: nil,
                isInitialCursor: false,
                writableRealm: writableRealm
            )

            if deleteOrphans {
                deleteOrphanFiles(root: root, newFiles: files, writableRealm: writableRealm)
            }
        }
    }

    /// Remove all children of to a root File with a transaction
    public func removeLocalFiles(root: File) {
        try? database.writeTransaction { writableRealm in
            guard let lastPicturesRootInContext = writableRealm
                .objects(File.self)
                .filter("id == %@", DriveFileManager.lastPicturesRootFile.id)
                .first else {
                return
            }

            for child in lastPicturesRootInContext.children {
                removeFileInDatabase(fileUid: child.uid, cascade: false, writableRealm: writableRealm)
            }
            writableRealm.add(lastPicturesRootInContext, update: .modified)
        }
    }

    public func lastModifiedFiles(cursor: String? = nil) async throws -> (files: [File], nextCursor: String?) {
        do {
            let lastModifiedFilesResponse = try await apiFetcher.lastModifiedFiles(drive: drive, cursor: cursor)
            let files = lastModifiedFilesResponse.validApiResponse.data

            setLocalFiles(files,
                          root: getManagedFile(from: DriveFileManager.lastModificationsRootFile),
                          deleteOrphans: cursor == nil)
            return (files.map { $0.freeze() }, lastModifiedFilesResponse.validApiResponse.cursor)
        } catch {
            if let files = getCachedFile(id: DriveFileManager.lastModificationsRootFile.id, freeze: true)?.children {
                return (Array(files), nil)
            } else {
                throw error
            }
        }
    }

    public func lastPictures(cursor: String? = nil) async throws -> (files: [File], nextCursor: String?) {
        do {
            let lastPicturesResponse = try await apiFetcher.searchFiles(
                drive: drive,
                fileTypes: [.image, .video],
                fileExtensions: [],
                categories: [],
                belongToAllCategories: false,
                cursor: cursor,
                sortType: .newer
            )
            let files = lastPicturesResponse.validApiResponse.data
            setLocalFiles(
                files,
                root: getManagedFile(from: DriveFileManager.lastPicturesRootFile),
                deleteOrphans: cursor == nil
            )

            return (files.map { $0.freeze() }, lastPicturesResponse.validApiResponse.cursor)
        } catch {
            if let files = getCachedFile(id: DriveFileManager.lastPicturesRootFile.id, freeze: true)?.children {
                return (Array(files), nil)
            } else {
                throw error
            }
        }
    }

    /// Fetch changes for a given directory and add it to DB
    /// - With API V3 there is no notion of activities. We only do a listing for an existing cursor
    public func fileActivities(file: ProxyFile) async throws {
        var (_, nextCursor) = try await fileListing(in: file)

        while nextCursor != nil {
            (_, nextCursor) = try await fileListing(in: file)
        }
    }

    func handleError(message: String, offlineFile file: File) {
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

    public func add(category: Category, to file: ProxyFile) async throws {
        let categoryId = category.id
        let response = try await apiFetcher.add(category: category, to: file)
        if response.result {
            updateFileProperty(fileUid: file.uid) { file in
                let newCategory = FileCategory(categoryId: categoryId, userId: self.drive.userId)
                file.categories.append(newCategory)
            }
        }
    }

    public func add(category: Category, to files: [ProxyFile]) async throws {
        let categoryId = category.id
        let response = try await apiFetcher.add(drive: drive, category: category, to: files)
        for fileResponse in response where fileResponse.result {
            updateFileProperty(fileUid: File.uid(driveId: drive.id, fileId: fileResponse.id)) { file in
                let newCategory = FileCategory(categoryId: categoryId, userId: self.drive.userId)
                file.categories.append(newCategory)
            }
        }
    }

    public func remove(category: Category, from file: ProxyFile) async throws {
        let categoryId = category.id
        let response = try await apiFetcher.remove(category: category, from: file)
        if response {
            updateFileProperty(fileUid: file.uid) { file in
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
            updateFileProperty(fileUid: File.uid(driveId: drive.id, fileId: fileResponse.id)) { file in
                if let index = file.categories.firstIndex(where: { $0.categoryId == categoryId }) {
                    file.categories.remove(at: index)
                }
            }
        }
    }

    public func createCategory(name: String, color: String) async throws -> Category {
        let category = try await apiFetcher.createCategory(drive: drive, name: name, color: color)
        // Add category to drive

        try? driveInfosManager.driveInfoDatabase.writeTransaction { writableRealm in
            let drive = driveInfosManager.getDrive(primaryKey: drive.objectId, freeze: false, using: writableRealm)
            guard let drive else {
                return
            }

            drive.categories.append(category)
            self.drive = drive.freeze()
        }

        return category.freeze()
    }

    public func edit(category: Category, name: String?, color: String) async throws -> Category {
        let categoryId = category.id
        let category = try await apiFetcher.editCategory(drive: drive, category: category, name: name, color: color)

        // Update category on drive
        try? driveInfosManager.driveInfoDatabase.writeTransaction { writableRealm in
            guard let drive = driveInfosManager.getDrive(primaryKey: drive.objectId, freeze: false, using: writableRealm)
            else {
                return
            }

            if let index = drive.categories.firstIndex(where: { $0.id == categoryId }) {
                drive.categories[index] = category
            }

            self.drive = drive.freeze()
        }

        return category
    }

    public func delete(category: Category) async throws -> Bool {
        let categoryId = category.id
        let response = try await apiFetcher.deleteCategory(drive: drive, category: category)

        guard response else {
            return response
        }

        // Delete category from drive
        try? driveInfosManager.driveInfoDatabase.writeTransaction { writableRealm in
            guard let drive = driveInfosManager.getDrive(primaryKey: drive.objectId, freeze: false, using: writableRealm)
            else {
                return
            }

            if let index = drive.categories.firstIndex(where: { $0.id == categoryId }) {
                drive.categories.remove(at: index)
            }

            self.drive = drive.freeze()
        }

        // Delete category from files
        try database.writeTransaction { writableRealm in
            let fetchedFiles = writableRealm.objects(File.self).filter("ANY categories.categoryId = %d", categoryId)
            for file in fetchedFiles {
                writableRealm.delete(file.categories.filter("categoryId = %d", categoryId))
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
            updateFileProperty(fileUid: file.uid) { file in
                file.isFavorite = favorite
            }
        }
    }

    public func delete(file: ProxyFile) async throws -> CancelableResponse {
        let response = try await apiFetcher.delete(file: file)
        Task {
            try? database.writeTransaction { writableRealm in
                let savedFile = try? file.resolve(using: writableRealm).freeze()
                removeFileInDatabase(fileUid: file.uid, cascade: true, writableRealm: writableRealm)

                if let file = savedFile {
                    savedFile?.signalChanges(userId: drive.userId)
                    notifyObserversWith(file: file)
                }

                deleteOrphanFiles(
                    root: DriveFileManager.homeRootFile,
                    DriveFileManager.lastModificationsRootFile,
                    DriveFileManager.searchFilesRootFile,
                    writableRealm: writableRealm
                )
            }
        }

        return response
    }

    public func move(file: ProxyFile, to destination: ProxyFile) async throws -> (CancelableResponse, File) {
        let response = try await apiFetcher.move(file: file, to: destination)

        // Add the moved file to Realm
        var updatedFile: File?
        try database.writeTransaction { writableRealm in
            let liveFile = try file.resolve(using: writableRealm)
            let newParent = try destination.resolve(using: writableRealm)
            let oldParent = liveFile.parent

            oldParent?.children.remove(liveFile)
            newParent.children.insert(liveFile)

            if let oldParent {
                oldParent.signalChanges(userId: drive.userId)
                notifyObserversWith(file: oldParent)
            }

            newParent.signalChanges(userId: drive.userId)
            notifyObserversWith(file: newParent)

            updatedFile = liveFile
        }

        guard let updatedFile else {
            throw DriveError.errorWithUserInfo(.fileNotFound, info: [.fileId: ErrorUserInfo(intValue: file.id)])
        }

        return (response, updatedFile)
    }

    public func rename(file: ProxyFile, newName: String) async throws -> File {
        _ = try await apiFetcher.rename(file: file, newName: newName)

        let fetchedFile = try file.resolve(within: self)
        let newFile = fetchedFile.detached()

        try database.writeTransaction { writableRealm in
            newFile.name = newName
            _ = try updateFileInDatabase(updatedFile: newFile, oldFile: fetchedFile, writableRealm: writableRealm)
            newFile.signalChanges(userId: drive.userId)
            notifyObserversWith(file: newFile)
        }

        return fetchedFile
    }

    public func duplicate(file: ProxyFile, duplicateName: String) async throws -> File {
        let duplicatedFile = try await apiFetcher.duplicate(file: file, duplicateName: duplicateName)

        var duplicateFile: File?
        try database.writeTransaction { writableRealm in
            let newFile = try updateFileInDatabase(updatedFile: duplicatedFile, writableRealm: writableRealm)
            duplicateFile = newFile

            let parent = try file.resolve(using: writableRealm).parent
            parent?.children.insert(newFile)

            newFile.signalChanges(userId: drive.userId)
            if let parent = duplicatedFile.parent {
                parent.signalChanges(userId: drive.userId)
                notifyObserversWith(file: parent)
            }
        }

        guard let duplicateFile else {
            throw DriveError.errorWithUserInfo(.fileNotFound, info: [.fileId: ErrorUserInfo(intValue: file.id)])
        }

        return duplicateFile
    }

    public func createDirectory(in parentDirectory: ProxyFile, name: String, onlyForMe: Bool) async throws -> File {
        let directory = try await apiFetcher.createDirectory(in: parentDirectory, name: name, onlyForMe: onlyForMe)

        var createdDirectory: File?
        try database.writeTransaction { writableRealm in
            let newDirectory = try updateFileInDatabase(updatedFile: directory, writableRealm: writableRealm)
            createdDirectory = newDirectory

            // Add directory to parent
            let parent = try? parentDirectory.resolve(using: writableRealm)
            parent?.children.insert(newDirectory)

            if let parent = newDirectory.parent {
                parent.signalChanges(userId: drive.userId)
                notifyObserversWith(file: parent)
            }
        }

        guard let createdDirectory else {
            throw DriveError.errorWithUserInfo(.fileNotFound, info: [.fileId: ErrorUserInfo(intValue: parentDirectory.id)])
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

        var liveDirectory: File?
        try database.writeTransaction { writableRealm in
            let directory = try updateFileInDatabase(updatedFile: createdDirectory, writableRealm: writableRealm)

            let parent = try? parentDirectory.resolve(using: writableRealm)
            directory.dropbox = dropbox
            parent?.children.insert(directory)

            if let parent = directory.parent {
                parent.signalChanges(userId: drive.userId)
                notifyObserversWith(file: parent)
            }

            liveDirectory = directory
        }

        guard let liveDirectory else {
            throw DriveError.errorWithUserInfo(.fileNotFound, info: [.fileId: ErrorUserInfo(intValue: parentDirectory.id)])
        }

        let frozenDirectory = liveDirectory.freeze()
        return frozenDirectory
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

        var liveFile: File?
        try database.writeTransaction { writableRealm in
            let createdFile = try updateFileInDatabase(updatedFile: file, writableRealm: writableRealm)
            // Add file to parent
            let parent = try? parentDirectory.resolve(using: writableRealm)
            parent?.children.insert(createdFile)
            createdFile.signalChanges(userId: drive.userId)

            if let parent = createdFile.parent {
                parent.signalChanges(userId: drive.userId)
                notifyObserversWith(file: parent)
            }

            liveFile = createdFile
        }

        guard let liveFile else {
            throw DriveError.errorWithUserInfo(.fileNotFound, info: [.fileId: ErrorUserInfo(intValue: parentDirectory.id)])
        }

        return liveFile.freeze()
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
        try? database.writeTransaction { writableRealm in
            let file = writableRealm.objects(File.self)
                .where { $0.externalImport.id == id }
                .first

            guard let file else {
                // No file corresponding to external import, ignore it
                return
            }

            switch action {
            case .importFinish:
                file.externalImport?.status = .done
            case .cancel:
                file.externalImport?.status = .failed
            default:
                break
            }
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

    public func writeChildrenToParent(
        _ children: [File],
        liveParent: File,
        responseAt: Int?,
        isInitialCursor: Bool,
        writableRealm: Realm
    ) throws {
        liveParent.responseAt = responseAt ?? Int(Date().timeIntervalSince1970)
        if children.count < Endpoint.itemsPerPage {
            liveParent.versionCode = DriveFileManager.constants.currentVersionCode
            liveParent.fullyDownloaded = true
        }
        writableRealm.add(children, update: .modified)

        // ⚠️ this is important because we are going to add all the children again. However, failing to start the request with
        // the first page will result in an undefined behavior.
        if isInitialCursor {
            liveParent.children.removeAll()
        }
        liveParent.children.insert(objectsIn: children)
    }

    func removeFileInDatabase(fileUid: String, cascade: Bool, writableRealm: Realm) {
        guard let rootLiveFile = writableRealm.object(ofType: File.self, forPrimaryKey: fileUid),
              !rootLiveFile.isInvalidated else {
            return
        }

        try? rootLiveFile.clearOnFileSystemIfNeeded()

        var fileUidsToProcess: [String] = rootLiveFile.children.map(\.uid)
        var liveFilesToDelete: [File] = [rootLiveFile]

        while !fileUidsToProcess.isEmpty {
            let currentFileUid = fileUidsToProcess.removeLast()
            guard let file = writableRealm.object(ofType: File.self, forPrimaryKey: currentFileUid), !file.isInvalidated else {
                continue
            }

            try? file.clearOnFileSystemIfNeeded()

            if cascade {
                let filesUidsToDelete = liveFilesToDelete.map { $0.uid }
                let liveChildren = file.children.filter { child in
                    // A child should not be a circular reference to an ancestor
                    return !child.isInvalidated && !filesUidsToDelete.contains(child.uid)
                }
                fileUidsToProcess.append(contentsOf: liveChildren.map { $0.uid })
                liveFilesToDelete.append(contentsOf: liveChildren)
            }
        }

        writableRealm.delete(liveFilesToDelete)
    }

    private func deleteOrphanFiles(root: File..., newFiles: [File]? = nil, writableRealm: Realm) {
        let rootIds: [Int] = root.map(\.id)
        let maybeOrphanFiles = writableRealm.objects(File.self)
            .filter("parentLink.@count == 1")
            .filter("ANY parentLink.id IN %@", rootIds)

        guard !maybeOrphanFiles.isEmpty else {
            return
        }

        var orphanFiles = [File]()

        for maybeOrphanFile in maybeOrphanFiles {
            if newFiles == nil || !(newFiles ?? []).contains(maybeOrphanFile) {
                if fileManager.fileExists(atPath: maybeOrphanFile.localContainerUrl.path) {
                    try? fileManager.removeItem(at: maybeOrphanFile.localContainerUrl) // Check that it was correctly removed?
                }
                orphanFiles.append(maybeOrphanFile)
            }
        }

        writableRealm.delete(orphanFiles)
    }

    private func updateFileProperty(fileUid: String, _ block: (File) -> Void) {
        try? database.writeTransaction { writableRealm in
            guard let file = writableRealm.object(ofType: File.self, forPrimaryKey: fileUid) else {
                return
            }

            block(file)
            notifyObserversWith(file: file)
        }
    }

    func updateFileInDatabase(updatedFile: File, oldFile: File? = nil) throws -> File {
        var file: File?
        try database.writeTransaction { writableRealm in
            file = try updateFileInDatabase(updatedFile: updatedFile, oldFile: oldFile, writableRealm: writableRealm)
        }

        guard let file else {
            throw DriveError.errorWithUserInfo(.fileNotFound, info: [:])
        }

        return file
    }

    func updateFileInDatabase(updatedFile: File, oldFile: File? = nil, writableRealm: Realm) throws -> File {
        // rename file if it was renamed in the drive
        if let oldFile {
            try renameCachedFile(updatedFile: updatedFile, oldFile: oldFile)
        }

        writableRealm.add(updatedFile, update: .modified)
        return updatedFile
    }

    public func renameCachedFile(updatedFile: File, oldFile: File) throws {
        if updatedFile.name != oldFile.name && fileManager.fileExists(atPath: oldFile.localUrl.path) {
            try fileManager.moveItem(atPath: oldFile.localUrl.path, toPath: updatedFile.localUrl.path)
        }
    }

    public struct FilePropertiesOptions: OptionSet {
        public let rawValue: Int

        public static let fullyDownloaded = FilePropertiesOptions(rawValue: 1 << 0)
        public static let children = FilePropertiesOptions(rawValue: 1 << 1)
        public static let responseAt = FilePropertiesOptions(rawValue: 1 << 2)
        public static let path = FilePropertiesOptions(rawValue: 1 << 3)
        public static let users = FilePropertiesOptions(rawValue: 1 << 4)
        public static let version = FilePropertiesOptions(rawValue: 1 << 5)
        public static let capabilities = FilePropertiesOptions(rawValue: 1 << 6)
        public static let lastCursor = FilePropertiesOptions(rawValue: 1 << 7)
        public static let lastActionAt = FilePropertiesOptions(rawValue: 1 << 8)

        public static let standard: FilePropertiesOptions = [.fullyDownloaded, .children, .responseAt, .lastActionAt, .lastCursor]
        public static let extras: FilePropertiesOptions = [.path, .users, .version]
        public static let all: FilePropertiesOptions = [
            .fullyDownloaded,
            .children,
            .responseAt,
            .lastActionAt,
            .lastCursor,
            .path,
            .users,
            .version,
            .capabilities
        ]

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public func keepCacheAttributesForFile(newFile: File, keepProperties: FilePropertiesOptions) {
        try? database.writeTransaction { writableRealm in
            keepCacheAttributesForFile(newFile: newFile, keepProperties: keepProperties, writableRealm: writableRealm)
        }
    }

    public func keepCacheAttributesForFile(newFile: File, keepProperties: FilePropertiesOptions, writableRealm: Realm) {
        guard let savedChild = writableRealm.object(ofType: File.self, forPrimaryKey: newFile.uid),
              !savedChild.isInvalidated else {
            return
        }

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
        if keepProperties.contains(.lastActionAt) {
            newFile.lastActionAt = savedChild.lastActionAt
        }
        if keepProperties.contains(.lastCursor) {
            newFile.lastCursor = savedChild.lastCursor
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

    public func undoAction(cancelId: String) async throws {
        try await apiFetcher.undoAction(drive: drive, cancelId: cancelId)
    }

    public func updateColor(directory: File, color: String) async throws -> Bool {
        let fileUid = directory.uid
        let result = try await apiFetcher.updateColor(directory: directory.proxify(), color: color)
        if result {
            updateFileProperty(fileUid: fileUid) { file in
                file.color = color
            }
        }
        return result
    }

    public func removeSearchChildren() {
        try? database.writeTransaction { writableRealm in
            let searchRoot = getManagedFile(from: DriveFileManager.searchFilesRootFile, writableRealm: writableRealm)

            searchRoot.fullyDownloaded = false
            searchRoot.children.removeAll()
        }
    }

    public func setFileAvailableOffline(file: File, available: Bool, completion: @escaping (Error?) -> Void) {
        guard let liveFile = getCachedFile(id: file.id, freeze: false) else {
            completion(DriveError.fileNotFound)
            return
        }

        let oldUrl = liveFile.localUrl
        let isLocalVersionOlderThanRemote = liveFile.isLocalVersionOlderThanRemote
        if available {
            updateFileProperty(fileUid: liveFile.uid) { writableFile in
                writableFile.isAvailableOffline = true
            }

            if !isLocalVersionOlderThanRemote {
                do {
                    try fileManager.createDirectory(at: liveFile.localContainerUrl, withIntermediateDirectories: true)
                    try fileManager.moveItem(at: oldUrl, to: liveFile.localUrl)
                    notifyObserversWith(file: liveFile)
                    completion(nil)
                } catch {
                    updateFileProperty(fileUid: liveFile.uid) { writableFile in
                        writableFile.isAvailableOffline = false
                    }

                    completion(error)
                }
            } else {
                let safeFile = liveFile.freeze()
                var token: ObservationToken?
                token = DownloadQueue.instance.observeFileDownloaded(self, fileId: safeFile.id) { _, error in
                    token?.cancel()
                    if error != nil && error != .taskRescheduled {
                        // Mark it as not available offline
                        self.updateFileProperty(fileUid: safeFile.uid) { writableFile in
                            writableFile.isAvailableOffline = false
                        }
                    }
                    self.notifyObserversWith(file: safeFile)
                    Task { @MainActor in
                        completion(error)
                    }
                }
                DownloadQueue.instance.addToQueue(file: safeFile, userId: drive.userId)
            }
        } else {
            updateFileProperty(fileUid: liveFile.uid) { writableFile in
                writableFile.isAvailableOffline = false
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

    public func setLocalRecentActivities(detachedActivities: [FileActivity]) async {
        try? database.writeTransaction { writableRealm in
            let homeRootFile = DriveFileManager.homeRootFile
            var activitiesSafe = [FileActivity]()
            for activity in detachedActivities {
                guard !activity.isInvalidated else {
                    continue
                }

                let safeActivity = FileActivity(value: activity)
                if let file = activity.file {
                    let safeFile = file.detached()
                    keepCacheAttributesForFile(newFile: safeFile, keepProperties: .all, writableRealm: writableRealm)
                    homeRootFile.children.insert(safeFile)
                    safeActivity.file = safeFile
                }
                activitiesSafe.append(safeActivity)
            }

            writableRealm.delete(writableRealm.objects(FileActivity.self))
            writableRealm.add(activitiesSafe, update: .modified)
            writableRealm.add(homeRootFile, update: .modified)

            let homeRootFileChildren = Array(homeRootFile.children)
            deleteOrphanFiles(
                root: homeRootFile,
                newFiles: homeRootFileChildren,
                writableRealm: writableRealm
            )
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
