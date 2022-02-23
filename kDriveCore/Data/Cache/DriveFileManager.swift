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
import InfomaniakLogin
import RealmSwift
import Sentry
import SwiftRegex

public class DriveFileManager {
    public class DriveFileManagerConstants {
        private let fileManager = FileManager.default
        public let rootDocumentsURL: URL
        public let importDirectoryURL: URL
        public let groupDirectoryURL: URL
        public let cacheDirectoryURL: URL
        public let openInPlaceDirectoryURL: URL?
        public let rootID = 1
        public let currentUploadDbVersion: UInt64 = 11
        public let currentVersionCode = 1
        public lazy var migrationBlock = { [weak self] (migration: Migration, oldSchemaVersion: UInt64) in
            guard let strongSelf = self else { return }
            if oldSchemaVersion < strongSelf.currentUploadDbVersion {
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
                        newObject!["conflictOption"] = ConflictOption.replace.rawValue
                    }
                }
            }
        }

        public lazy var uploadsRealmConfiguration = Realm.Configuration(
            fileURL: rootDocumentsURL.appendingPathComponent("uploads.realm"),
            schemaVersion: currentUploadDbVersion,
            migrationBlock: migrationBlock,
            objectTypes: [DownloadTask.self, UploadFile.self, PhotoSyncSettings.self])

        public var uploadsRealm: Realm {
            do {
                return try Realm(configuration: uploadsRealmConfiguration)
            } catch {
                // We can't recover from this error but at least we report it correctly on Sentry
                Logging.reportRealmOpeningError(error, realmConfiguration: uploadsRealmConfiguration)
            }
        }

        init() {
            groupDirectoryURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AccountManager.appGroup)!
            rootDocumentsURL = groupDirectoryURL.appendingPathComponent("drives", isDirectory: true)
            importDirectoryURL = groupDirectoryURL.appendingPathComponent("import", isDirectory: true)
            cacheDirectoryURL = groupDirectoryURL.appendingPathComponent("Library/Caches", isDirectory: true)
            openInPlaceDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(".shared", isDirectory: true)
            try? fileManager.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: groupDirectoryURL.path)
            try? FileManager.default.createDirectory(atPath: rootDocumentsURL.path, withIntermediateDirectories: true, attributes: nil)
            try? FileManager.default.createDirectory(atPath: importDirectoryURL.path, withIntermediateDirectories: true, attributes: nil)
            try? FileManager.default.createDirectory(atPath: cacheDirectoryURL.path, withIntermediateDirectories: true, attributes: nil)

            DDLogInfo("App working path is: \(fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.absoluteString ?? "")")
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

    public func getCachedRootFile(using realm: Realm? = nil) -> File {
        if let root = getCachedFile(id: DriveFileManager.constants.rootID, freeze: false) {
            if root.name != drive.name {
                let realm = realm ?? getRealm()
                try? realm.safeWrite {
                    root.name = drive.name
                }
            }
            return root.freeze()
        } else {
            return File(id: DriveFileManager.constants.rootID, name: drive.name)
        }
    }

    let backgroundQueue = DispatchQueue(label: "background-db", autoreleaseFrequency: .workItem)
    public var realmConfiguration: Realm.Configuration
    public var drive: Drive
    public private(set) var apiFetcher: DriveApiFetcher

    private var didUpdateFileObservers = [UUID: (File) -> Void]()

    init(drive: Drive, apiFetcher: DriveApiFetcher) {
        self.drive = drive
        self.apiFetcher = apiFetcher
        let realmName = "\(drive.userId)-\(drive.id).realm"
        realmConfiguration = Realm.Configuration(
            fileURL: DriveFileManager.constants.rootDocumentsURL.appendingPathComponent(realmName),
            schemaVersion: 8,
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 1 {
                    // Migration to version 1: migrating rights
                    migration.enumerateObjects(ofType: Rights.className()) { oldObject, newObject in
                        newObject?["show"] = oldObject?["show"] ?? false
                        newObject?["read"] = oldObject?["read"] ?? false
                        newObject?["write"] = oldObject?["write"] ?? false
                        newObject?["share"] = oldObject?["share"] ?? false
                        newObject?["leave"] = oldObject?["leave"] ?? false
                        newObject?["delete"] = oldObject?["delete"] ?? false
                        newObject?["rename"] = oldObject?["rename"] ?? false
                        newObject?["move"] = oldObject?["move"] ?? false
                        newObject?["createNewFolder"] = oldObject?["createNewFolder"] ?? false
                        newObject?["createNewFile"] = oldObject?["createNewFile"] ?? false
                        newObject?["uploadNewFile"] = oldObject?["uploadNewFile"] ?? false
                        newObject?["moveInto"] = oldObject?["moveInto"] ?? false
                        newObject?["canBecomeCollab"] = oldObject?["canBecomeCollab"] ?? false
                        newObject?["canBecomeLink"] = oldObject?["canBecomeLink"] ?? false
                        newObject?["canFavorite"] = oldObject?["canFavorite"] ?? false
                    }
                }
                if oldSchemaVersion < 5 {
                    // Get file ids
                    var fileIds = Set<Int>()
                    migration.enumerateObjects(ofType: File.className()) { oldObject, _ in
                        if let id = oldObject?["id"] as? Int {
                            fileIds.insert(id)
                        }
                    }
                    // Remove dangling rights
                    migration.enumerateObjects(ofType: Rights.className()) { oldObject, newObject in
                        guard let newObject = newObject, let fileId = oldObject?["fileId"] as? Int else { return }
                        if !fileIds.contains(fileId) {
                            migration.delete(newObject)
                        }
                    }
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
                        newObject?["lastModifiedAt"] = Date(timeIntervalSince1970: TimeInterval(oldObject?["lastModifiedAt"] as? Int ?? 0))
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
            objectTypes: [File.self, Rights.self, FileActivity.self, FileCategory.self, FileConversion.self, FileVersion.self, ShareLink.self, ShareLinkCapabilities.self, DropBox.self, DropBoxCapabilities.self, DropBoxSize.self, DropBoxValidity.self])

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
            objectTypes: [Drive.self, DrivePackFunctionality.self, DrivePreferences.self, DriveUsersCategories.self, DriveTeamsCategories.self, DriveUser.self, Team.self, TeamDetail.self, Category.self, CategoryRights.self])
        do {
            _ = try Realm(configuration: config)
        } catch {
            DDLogError("Failed to compact drive infos realm: \(error)")
        }

        let files = (try? fileManager.contentsOfDirectory(at: DriveFileManager.constants.rootDocumentsURL, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "realm" {
            do {
                let realmConfiguration = Realm.Configuration(
                    fileURL: file,
                    deleteRealmIfMigrationNeeded: true,
                    shouldCompactOnLaunch: compactingCondition,
                    objectTypes: [File.self, Rights.self, FileActivity.self])
                _ = try Realm(configuration: realmConfiguration)
            } catch {
                DDLogError("Failed to compact realm: \(error)")
            }
        }
    }

    public func getRealm() -> Realm {
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
        let files = (try? FileManager.default.contentsOfDirectory(at: DriveFileManager.constants.rootDocumentsURL, includingPropertiesForKeys: nil))
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
        let file = realm.object(ofType: File.self, forPrimaryKey: id)
        return freeze ? file?.freeze() : file
    }

    public func initRoot() async throws {
        let root = try await file(id: DriveFileManager.constants.rootID, forceRefresh: true)
        _ = try await files(in: root)
    }

    public func files(in directory: File, page: Int = 1, sortType: SortType = .nameAZ, forceRefresh: Bool = false) async throws -> (files: [File], moreComing: Bool) {
        let parentId = directory.id
        if let cachedParent = getCachedFile(id: parentId, freeze: false),
           // We have cache and we show it before fetching activities OR we are not connected to internet and we show what we have anyway
           (cachedParent.fullyDownloaded && cachedParent.versionCode == DriveFileManager.constants.currentVersionCode && !forceRefresh) || ReachabilityListener.instance.currentStatus == .offline {
            return (getLocalSortedDirectoryFiles(directory: cachedParent, sortType: sortType), false)
        } else {
            // Get children from API
            let children: [File]
            let responseAt: Int?
            if directory.isRoot {
                (children, responseAt) = try await apiFetcher.rootFiles(drive: drive, page: page, sortType: sortType)
            } else {
                (children, responseAt) = try await apiFetcher.files(in: directory, page: page, sortType: sortType)
            }

            let realm = getRealm()

            // Keep cached properties for children
            for child in children {
                keepCacheAttributesForFile(newFile: child, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
            }

            if let managedParent = realm.object(ofType: File.self, forPrimaryKey: parentId) {
                // Update parent
                try realm.write {
                    managedParent.responseAt = responseAt ?? Int(Date().timeIntervalSince1970)
                    if children.count < Endpoint.itemsPerPage {
                        managedParent.versionCode = DriveFileManager.constants.currentVersionCode
                        managedParent.fullyDownloaded = true
                    }
                    realm.add(children, update: .modified)
                    // ⚠️ this is important because we are going to add all the children again. However, failing to start the request with the first page will result in an undefined behavior.
                    if page == 1 {
                        managedParent.children.removeAll()
                    }
                    managedParent.children.insert(objectsIn: children)
                }

                return (getLocalSortedDirectoryFiles(directory: managedParent, sortType: sortType), children.count == Endpoint.itemsPerPage)
            } else {
                throw DriveError.errorWithUserInfo(.fileNotFound, info: [.fileId: ErrorUserInfo(intValue: parentId)])
            }
        }
    }

    public func file(id: Int, forceRefresh: Bool = false) async throws -> File {
        if let cachedFile = getCachedFile(id: id),
           // We have cache and we show it before fetching activities OR we are not connected to internet and we show what we have anyway
           (cachedFile.responseAt > 0 && !forceRefresh) || ReachabilityListener.instance.currentStatus == .offline {
            return cachedFile
        } else {
            let (file, _) = try await apiFetcher.fileInfo(ProxyFile(driveId: drive.id, id: id))

            let realm = getRealm()

            // Keep cached properties for file
            keepCacheAttributesForFile(newFile: file, keepStandard: true, keepExtras: false, keepRights: false, using: realm)

            // Update file in Realm
            try? realm.safeWrite {
                realm.add(file, update: .modified)
            }

            return file.freeze()
        }
    }

    typealias FileApiSignature = (AbstractDrive, Int, SortType) async throws -> [File]

    private func files(at root: File, apiMethod: FileApiSignature, page: Int, sortType: SortType) async throws -> (files: [File], moreComing: Bool) {
        do {
            let files = try await apiMethod(drive, page, sortType)

            let localRealm = getRealm()
            for file in files {
                keepCacheAttributesForFile(newFile: file, keepStandard: true, keepExtras: true, keepRights: false, using: localRealm)
            }

            if files.count < Endpoint.itemsPerPage {
                root.fullyDownloaded = true
            }

            root.children.insert(objectsIn: files)
            let updatedFile = try updateFileInDatabase(updatedFile: root, using: localRealm)

            return (getLocalSortedDirectoryFiles(directory: updatedFile, sortType: sortType), files.count == Endpoint.itemsPerPage)
        } catch {
            if page == 1, let root = getCachedFile(id: root.id) {
                return (getLocalSortedDirectoryFiles(directory: root, sortType: sortType), false)
            } else {
                throw error
            }
        }
    }

    public func favorites(page: Int = 1, sortType: SortType = .nameAZ) async throws -> (files: [File], moreComing: Bool) {
        try await files(at: DriveFileManager.favoriteRootFile, apiMethod: apiFetcher.favorites, page: page, sortType: sortType)
    }

    public func mySharedFiles(page: Int = 1, sortType: SortType = .nameAZ) async throws -> (files: [File], moreComing: Bool) {
        try await files(at: DriveFileManager.mySharedRootFile, apiMethod: apiFetcher.mySharedFiles, page: page, sortType: sortType)
    }

    public func getAvailableOfflineFiles(sortType: SortType = .nameAZ) -> [File] {
        let offlineFiles = getRealm().objects(File.self)
            .filter(NSPredicate(format: "isAvailableOffline = true"))
            .sorted(by: [sortType.value.sortDescriptor]).freeze()

        return offlineFiles.map { $0.freeze() }
    }

    public func searchFile(query: String? = nil, date: DateInterval? = nil, fileType: ConvertedType? = nil, categories: [Category], belongToAllCategories: Bool, page: Int = 1, sortType: SortType = .nameAZ) async throws -> (files: [File], moreComing: Bool) {
        if ReachabilityListener.instance.currentStatus == .offline {
            let localFiles = searchOffline(query: query, date: date, fileType: fileType, categories: categories, belongToAllCategories: belongToAllCategories, sortType: sortType)
            return (localFiles, false)
        } else {
            do {
                let files = try await apiFetcher.searchFiles(drive: drive, query: query, date: date, fileType: fileType, categories: categories, belongToAllCategories: belongToAllCategories, page: page, sortType: sortType)
                let realm = getRealm()
                let searchRoot = DriveFileManager.searchFilesRootFile
                if files.count < Endpoint.itemsPerPage {
                    searchRoot.fullyDownloaded = true
                }
                for file in files {
                    keepCacheAttributesForFile(newFile: file, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
                }

                setLocalFiles(files, root: searchRoot)
                return (files.map { $0.freeze() }, files.count == Endpoint.itemsPerPage)
            } catch {
                if error.asAFError?.isExplicitlyCancelledError == true {
                    throw DriveError.searchCancelled
                } else {
                    let localFiles = searchOffline(query: query, date: date, fileType: fileType, categories: categories, belongToAllCategories: belongToAllCategories, sortType: sortType)
                    return (localFiles, false)
                }
            }
        }
    }

    private func searchOffline(query: String? = nil, date: DateInterval? = nil, fileType: ConvertedType? = nil, categories: [Category], belongToAllCategories: Bool, sortType: SortType = .nameAZ) -> [File] {
        let realm = getRealm()
        var searchResults = realm.objects(File.self).filter("id > 0")
        if let query = query, !query.isBlank {
            searchResults = searchResults.filter(NSPredicate(format: "name CONTAINS[cd] %@", query))
        }
        if let date = date {
            searchResults = searchResults.filter(NSPredicate(format: "lastModifiedAt >= %d && lastModifiedAt <= %d", Int(date.start.timeIntervalSince1970), Int(date.end.timeIntervalSince1970)))
        }
        if let fileType = fileType {
            if fileType == .folder {
                searchResults = searchResults.filter(NSPredicate(format: "rawType == \"dir\""))
            } else {
                searchResults = searchResults.filter(NSPredicate(format: "rawConvertedType == %@", fileType.rawValue))
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
        var allFiles = [File]()

        if query != nil || fileType != nil {
            searchResults = searchResults.sorted(by: [sortType.value.sortDescriptor])
            for child in searchResults.freeze() { allFiles.append(child.freeze()) }
        }

        let searchRoot = DriveFileManager.searchFilesRootFile
        searchRoot.fullyDownloaded = true

        return allFiles
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
                    DispatchQueue.main.async {
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
            DownloadQueue.instance.operation(for: file)?.cancel()
            try? fileManager.createDirectory(at: file.localContainerUrl, withIntermediateDirectories: true)
            try? fileManager.moveItem(at: oldUrl, to: file.localUrl)
            notifyObserversWith(file: file)
            try? fileManager.removeItem(at: oldUrl)
            completion(nil)
        }
    }

    public func setFileShareLink(file: File, shareLink: ShareLink?) {
        updateFileProperty(fileId: file.id) { file in
            file.sharelink = shareLink
            file.capabilities.canBecomeSharelink = shareLink == nil
        }
    }

    public func setFileDropBox(file: File, dropBox: DropBox?) {
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
                let safeActivity = FileActivity(value: activity)
                if let file = activity.file {
                    let safeFile = File(value: file)
                    keepCacheAttributesForFile(newFile: safeFile, keepStandard: true, keepExtras: true, keepRights: true, using: realm)
                    homeRootFile.children.insert(safeFile)
                    safeActivity.file = safeFile
                    safeActivity.file?.capabilities = Rights(value: file.capabilities)
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

    public func setLocalFiles(_ files: [File], root: File) {
        let realm = getRealm()
        for file in files {
            root.children.insert(file)
            file.capabilities = Rights(value: file.capabilities)
        }

        try? realm.safeWrite {
            realm.add(root, update: .modified)
        }
        deleteOrphanFiles(root: root, newFiles: files, using: realm)
    }

    public func lastModifiedFiles(page: Int = 1) async throws -> (files: [File], moreComing: Bool) {
        do {
            let files = try await apiFetcher.lastModifiedFiles(drive: drive, page: page)
            let realm = getRealm()
            for file in files {
                keepCacheAttributesForFile(newFile: file, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
            }

            setLocalFiles(files, root: DriveFileManager.lastModificationsRootFile)
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
            let files = try await apiFetcher.searchFiles(drive: drive, fileType: .image, categories: [], belongToAllCategories: false, page: page, sortType: .newer)
            let realm = getRealm()
            for file in files {
                keepCacheAttributesForFile(newFile: file, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
            }

            setLocalFiles(files, root: DriveFileManager.lastPicturesRootFile)
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

    public func fileActivities(file: File, from timestamp: Int? = nil) async throws -> (result: ActivitiesResult, responseAt: Int) {
        // Get all pages and assemble
        let fileId = file.id
        let timestamp = TimeInterval(timestamp ?? file.responseAt)
        var page = 1
        var moreComing = true
        var pagedActions = [Int: FileActivityType]()
        var pagedActivities = ActivitiesResult()
        var responseAt = 0
        while moreComing {
            // Get activities page
            let (activities, pageResponseAt) = try await apiFetcher.fileActivities(file: file, from: Date(timeIntervalSince1970: timestamp), page: page)
            moreComing = activities.count == Endpoint.itemsPerPage
            page += 1
            responseAt = pageResponseAt ?? Int(Date().timeIntervalSince1970)
            // Get file from Realm
            let realm = getRealm()
            guard let file = realm.object(ofType: File.self, forPrimaryKey: fileId) else {
                throw DriveError.fileNotFound
            }
            // Apply activities to file
            let results = apply(activities: activities, to: file, pagedActions: &pagedActions, timestamp: responseAt, using: realm)
            pagedActivities.inserted.insert(contentsOf: results.inserted, at: 0)
            pagedActivities.updated.insert(contentsOf: results.updated, at: 0)
            pagedActivities.deleted.insert(contentsOf: results.deleted, at: 0)
        }
        return (pagedActivities, responseAt)
    }

    // swiftlint:disable cyclomatic_complexity
    private func apply(activities: [FileActivity],
                       to file: File,
                       pagedActions: inout [Int: FileActivityType],
                       timestamp: Int,
                       using realm: Realm? = nil) -> ActivitiesResult {
        var insertedFiles = [File]()
        var updatedFiles = [File]()
        var deletedFiles = [File]()
        let realm = realm ?? getRealm()
        realm.beginWrite()
        for activity in activities {
            let fileId = activity.fileId
            if pagedActions[fileId] == nil {
                switch activity.action {
                case .fileDelete, .fileTrash:
                    if let file = realm.object(ofType: File.self, forPrimaryKey: fileId) {
                        deletedFiles.append(file.freeze())
                    }
                    removeFileInDatabase(fileId: fileId, cascade: true, withTransaction: false, using: realm)
                    if let file = activity.file {
                        deletedFiles.append(file)
                    }
                    pagedActions[fileId] = .fileDelete
                case .fileMoveOut:
                    if let file = realm.object(ofType: File.self, forPrimaryKey: fileId),
                       let oldParent = file.parent {
                        oldParent.children.remove(file)
                    }
                    if let file = activity.file {
                        deletedFiles.append(file)
                    }
                    pagedActions[fileId] = .fileDelete
                case .fileRename:
                    if let oldFile = realm.object(ofType: File.self, forPrimaryKey: fileId),
                       let renamedFile = activity.file {
                        try? renameCachedFile(updatedFile: renamedFile, oldFile: oldFile)
                        // If the file is a folder we have to copy the old attributes which are not returned by the API
                        keepCacheAttributesForFile(newFile: renamedFile, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
                        realm.add(renamedFile, update: .modified)
                        file.children.insert(renamedFile)
                        renamedFile.applyLastModifiedDateToLocalFile()
                        updatedFiles.append(renamedFile)
                        pagedActions[fileId] = .fileUpdate
                    }
                case .fileMoveIn, .fileRestore, .fileCreate:
                    if let newFile = activity.file {
                        keepCacheAttributesForFile(newFile: newFile, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
                        realm.add(newFile, update: .modified)
                        // If was already had a local parent, remove it
                        if let file = realm.object(ofType: File.self, forPrimaryKey: fileId),
                           let oldParent = file.parent {
                            oldParent.children.remove(file)
                        }
                        file.children.insert(newFile)
                        insertedFiles.append(newFile)
                        pagedActions[fileId] = .fileCreate
                    }
                case .fileFavoriteCreate, .fileFavoriteRemove, .fileUpdate, .fileShareCreate, .fileShareUpdate, .fileShareDelete, .collaborativeFolderCreate, .collaborativeFolderUpdate, .collaborativeFolderDelete, .fileColorUpdate, .fileColorDelete:
                    if let newFile = activity.file {
                        keepCacheAttributesForFile(newFile: newFile, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
                        realm.add(newFile, update: .modified)
                        file.children.insert(newFile)
                        updatedFiles.append(newFile)
                        pagedActions[fileId] = .fileUpdate
                    }
                default:
                    break
                }
            }
        }
        file.responseAt = timestamp
        try? realm.commitWrite()
        return ActivitiesResult(inserted: insertedFiles.map { $0.freeze() }, updated: updatedFiles.map { $0.freeze() }, deleted: deletedFiles)
    }

    public func filesActivities(files: [File], from date: Date) async throws -> [ActivitiesForFile] {
        let (result, responseAt) = try await apiFetcher.filesActivities(drive: drive, files: files, from: date)
        // Update last sync date
        if let responseAt = responseAt {
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
            keepCacheAttributesForFile(newFile: newFile, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
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
            SentrySDK.capture(message: message)
        }
        // Silently handle error
        DDLogError("Error while fetching [\(file.id) - \(file.name)] in [\(drive.id) - \(drive.name)]: \(message)")
    }

    public func getWorkingSet() -> [File] {
        // let predicate = NSPredicate(format: "isFavorite = %d OR lastModifiedAt >= %d", true, Int(Date(timeIntervalSinceNow: -3600).timeIntervalSince1970))
        let files = getRealm().objects(File.self).sorted(by: \.lastModifiedAt, ascending: false)
        var result = [File]()
        for i in 0 ..< min(20, files.count) {
            result.append(files[i])
        }
        return result
    }

    public func add(category: Category, to file: File) async throws {
        let fileId = file.id
        let categoryId = category.id
        let response = try await apiFetcher.add(category: category, to: file)
        if response {
            updateFileProperty(fileId: fileId) { file in
                let newCategory = FileCategory(categoryId: categoryId, userId: self.drive.userId)
                file.categories.append(newCategory)
            }
        }
    }

    public func remove(category: Category, from file: File) async throws {
        let fileId = file.id
        let categoryId = category.id
        let response = try await apiFetcher.remove(category: category, from: file)
        if response {
            updateFileProperty(fileId: fileId) { file in
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
        let drive = DriveInfosManager.instance.getDrive(objectId: self.drive.objectId, freeze: false, using: realm)
        try? realm.write {
            drive?.categories.append(category)
        }
        if let drive = drive {
            self.drive = drive.freeze()
        }
        return category
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

    public func setFavorite(file: File, favorite: Bool) async throws {
        let fileId = file.id
        if favorite {
            let response = try await apiFetcher.favorite(file: file)
            if response {
                updateFileProperty(fileId: fileId) { file in
                    file.isFavorite = true
                }
            }
        } else {
            let response = try await apiFetcher.unfavorite(file: file)
            if response {
                updateFileProperty(fileId: fileId) { file in
                    file.isFavorite = false
                }
            }
        }
    }

    public func delete(file: File) async throws -> CancelableResponse {
        let fileId = file.id
        let response = try await apiFetcher.delete(file: file)
        file.signalChanges(userId: drive.userId)
        backgroundQueue.async { [self] in
            let localRealm = getRealm()
            let savedFile = getCachedFile(id: fileId, using: localRealm)
            removeFileInDatabase(fileId: fileId, cascade: true, withTransaction: true, using: localRealm)
            if let file = savedFile {
                self.notifyObserversWith(file: file)
            }
            deleteOrphanFiles(root: DriveFileManager.homeRootFile, DriveFileManager.lastPicturesRootFile, DriveFileManager.lastModificationsRootFile, DriveFileManager.searchFilesRootFile, using: localRealm)
        }
        return response
    }

    public func move(file: File, to destination: File) async throws -> (CancelableResponse, File) {
        guard file.isManagedByRealm && destination.isManagedByRealm else {
            throw DriveError.fileNotFound
        }
        let safeFile = ThreadSafeReference(to: file)
        let safeParent = ThreadSafeReference(to: destination)
        let response = try await apiFetcher.move(file: file, to: destination)
        // Add the moved file to Realm
        let realm = getRealm()
        if let newParent = realm.resolve(safeParent),
           let file = realm.resolve(safeFile) {
            let oldParent = file.parent
            try? realm.write {
                oldParent?.children.remove(file)
                newParent.children.insert(file)
            }
            if let oldParent = oldParent {
                oldParent.signalChanges(userId: drive.userId)
                notifyObserversWith(file: oldParent)
            }
            newParent.signalChanges(userId: drive.userId)
            notifyObserversWith(file: newParent)
            return (response, file)
        } else {
            throw DriveError.unknownError
        }
    }

    public func rename(file: File, newName: String) async throws -> File {
        guard file.isManagedByRealm else {
            throw DriveError.fileNotFound
        }
        let safeFile = ThreadSafeReference(to: file)
        _ = try await apiFetcher.rename(file: file, newName: newName)
        let realm = getRealm()
        if let file = realm.resolve(safeFile) {
            try realm.write {
                file.name = newName
            }
            file.signalChanges(userId: drive.userId)
            notifyObserversWith(file: file)
            return file
        } else {
            throw DriveError.fileNotFound
        }
    }

    public func duplicate(file: File, duplicateName: String) async throws -> File {
        let parentId = file.parent?.id
        let file = try await apiFetcher.duplicate(file: file, duplicateName: duplicateName)
        let realm = getRealm()
        let duplicateFile = try updateFileInDatabase(updatedFile: file, using: realm)
        let parent = realm.object(ofType: File.self, forPrimaryKey: parentId)
        try realm.safeWrite {
            parent?.children.insert(duplicateFile)
        }

        duplicateFile.signalChanges(userId: drive.userId)
        if let parent = file.parent {
            parent.signalChanges(userId: drive.userId)
            notifyObserversWith(file: parent)
        }
        return duplicateFile
    }

    public func createDirectory(in parentDirectory: File, name: String, onlyForMe: Bool) async throws -> File {
        let parentId = parentDirectory.id
        let directory = try await apiFetcher.createDirectory(in: parentDirectory, name: name, onlyForMe: onlyForMe)
        let realm = getRealm()
        let createdDirectory = try updateFileInDatabase(updatedFile: directory, using: realm)
        // Add directory to parent
        let parent = realm.object(ofType: File.self, forPrimaryKey: parentId)
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

    public func createDropBox(parentDirectory: File, name: String, onlyForMe: Bool, settings: DropBoxSettings) async throws -> File {
        let parentId = parentDirectory.id
        // Create directory
        let createdDirectory = try await apiFetcher.createDirectory(in: parentDirectory, name: name, onlyForMe: onlyForMe)
        // Set up dropbox
        let dropbox = try await apiFetcher.createDropBox(directory: createdDirectory, settings: settings)
        let realm = getRealm()
        let directory = try updateFileInDatabase(updatedFile: createdDirectory, using: realm)

        let parent = realm.object(ofType: File.self, forPrimaryKey: parentId)
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

    public func updateDropBox(directory: File, settings: DropBoxSettings) async throws -> Bool {
        let proxyFile = File(value: directory)
        let response = try await apiFetcher.updateDropBox(directory: directory, settings: settings)
        if response {
            // Update dropbox in Realm
            let dropbox = try await apiFetcher.getDropBox(directory: proxyFile)
            setFileDropBox(file: proxyFile, dropBox: dropbox)
        }
        return response
    }

    public func createFile(in parentDirectory: File, name: String, type: String) async throws -> File {
        let parentId = parentDirectory.id
        let file = try await apiFetcher.createFile(in: parentDirectory, name: name, type: type)
        let realm = getRealm()
        let createdFile = try updateFileInDatabase(updatedFile: file, using: realm)
        // Add file to parent
        let parent = realm.object(ofType: File.self, forPrimaryKey: parentId)
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

    public func createOrRemoveShareLink(for file: File, right: ShareLinkPermission) async throws -> ShareLink? {
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

    public func createShareLink(for file: File) async throws -> ShareLink {
        let proxyFile = File(id: file.id, name: file.name)
        let shareLink = try await apiFetcher.createShareLink(for: file)
        // Fix for API not returning share link activities
        setFileShareLink(file: proxyFile, shareLink: shareLink)
        return shareLink.freeze()
    }

    public func updateShareLink(for file: File, settings: ShareLinkSettings) async throws -> Bool {
        let proxyFile = File(value: file)
        let response = try await apiFetcher.updateShareLink(for: file, settings: settings)
        if response {
            // Update sharelink in Realm
            let shareLink = try await apiFetcher.shareLink(for: file)
            setFileShareLink(file: proxyFile, shareLink: shareLink)
        }
        return response
    }

    public func removeShareLink(for file: File) async throws -> Bool {
        let proxyFile = File(id: file.id, name: file.name)
        let response = try await apiFetcher.removeShareLink(for: file)
        if response {
            // Fix for API not returning share link activities
            setFileShareLink(file: proxyFile, shareLink: nil)
        }
        return response
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
        if let file = realm.object(ofType: File.self, forPrimaryKey: fileId) {
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
        let maybeOrphanFiles = realm.objects(File.self).filter("parentLink.@count == 1").filter(NSPredicate(format: "ANY parentLink.id IN %@", root.map(\.id)))
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
        if let file = realm.object(ofType: File.self, forPrimaryKey: fileId) {
            try? realm.write {
                block(file)
            }
            notifyObserversWith(file: file)
        }
    }

    private func updateFileInDatabase(updatedFile: File, oldFile: File? = nil, using realm: Realm? = nil) throws -> File {
        let realm = realm ?? getRealm()
        // rename file if it was renamed in the drive
        if let oldFile = oldFile {
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

    private func keepCacheAttributesForFile(newFile: File, keepStandard: Bool, keepExtras: Bool, keepRights: Bool, using realm: Realm? = nil) {
        let realm = realm ?? getRealm()
        if let savedChild = realm.object(ofType: File.self, forPrimaryKey: newFile.id) {
            newFile.isAvailableOffline = savedChild.isAvailableOffline
            newFile.versionCode = savedChild.versionCode
            if keepStandard {
                newFile.fullyDownloaded = savedChild.fullyDownloaded
                newFile.children = savedChild.children
                newFile.responseAt = savedChild.responseAt
            }
            if keepExtras {
                newFile.path = savedChild.path
                newFile.users = savedChild.users.freeze()
                if let version = savedChild.version {
                    newFile.version = FileVersion(value: version)
                }
            }
            if keepRights {
                newFile.capabilities = savedChild.capabilities
            }
        }
    }

    public func undoAction(cancelId: String) async throws {
        try await apiFetcher.undoAction(drive: drive, cancelId: cancelId)
    }

    public func updateColor(directory: File, color: String) async throws -> Bool {
        let fileId = directory.id
        let result = try await apiFetcher.updateColor(directory: directory, color: color)
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
        let file = file.isFrozen ? file : file.freeze()
        for observer in didUpdateFileObservers.values {
            observer(file)
        }
    }
}
