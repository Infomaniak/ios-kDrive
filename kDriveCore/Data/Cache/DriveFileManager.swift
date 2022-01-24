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

    public func getRootFile(using realm: Realm? = nil) -> File {
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
            schemaVersion: 6,
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
            },
            objectTypes: [File.self, Rights.self, FileActivity.self, FileCategory.self])

        // Only compact in the background
        /* if !Constants.isInExtension && UIApplication.shared.applicationState == .background {
             compactRealmsIfNeeded()
         } */

        // Get root file
        let realm = getRealm()
        if getCachedFile(id: DriveFileManager.constants.rootID, freeze: false, using: realm) == nil {
            let rootFile = getRootFile(using: realm)
            try? realm.safeWrite {
                realm.add(rootFile)
            }
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

    public func getFile(id: Int, withExtras: Bool = false, page: Int = 1, sortType: SortType = .nameAZ, forceRefresh: Bool = false, completion: @escaping (File?, [File]?, Error?) -> Void) {
        let realm = getRealm()
        if var cachedFile = realm.object(ofType: File.self, forPrimaryKey: id),
           // We have cache and we show it before fetching activities OR we are not connected to internet and we show what we have anyway
           (cachedFile.fullyDownloaded && !forceRefresh && cachedFile.responseAt > 0 && !withExtras) || ReachabilityListener.instance.currentStatus == .offline {
            // Sometimes realm isn't up to date
            realm.refresh()
            cachedFile = cachedFile.freeze()
            backgroundQueue.async {
                let sortedChildren = self.getLocalSortedDirectoryFiles(directory: cachedFile, sortType: sortType)
                DispatchQueue.main.async {
                    completion(cachedFile, sortedChildren, nil)
                }
            }
        } else {
            if !withExtras {
                apiFetcher.getFileListForDirectory(driveId: drive.id, parentId: id, page: page, sortType: sortType) { [self] response, error in
                    if let file = response?.data {
                        backgroundQueue.async {
                            autoreleasepool {
                                if file.id == DriveFileManager.constants.rootID {
                                    file.name = drive.name
                                }
                                file.responseAt = response?.responseAt ?? 0

                                let localRealm = getRealm()
                                keepCacheAttributesForFile(newFile: file, keepStandard: false, keepExtras: true, keepRights: false, using: localRealm)
                                for child in file.children {
                                    keepCacheAttributesForFile(newFile: child, keepStandard: true, keepExtras: true, keepRights: false, using: localRealm)
                                }

                                if file.children.count < DriveApiFetcher.itemPerPage {
                                    file.fullyDownloaded = true
                                }

                                do {
                                    var updatedFile: File!

                                    if page > 1 {
                                        // Only 25 children are returned by the API, we have to add the previous children to our file
                                        updatedFile = try self.updateFileChildrenInDatabase(file: file, using: localRealm)
                                    } else {
                                        // No children, we only update file in db
                                        updatedFile = try self.updateFileInDatabase(updatedFile: file, using: localRealm)
                                    }

                                    let frozenFile = updatedFile.freeze()
                                    let sortedChildren = getLocalSortedDirectoryFiles(directory: updatedFile, sortType: sortType)
                                    DispatchQueue.main.async {
                                        completion(frozenFile, sortedChildren, nil)
                                    }
                                } catch {
                                    DispatchQueue.main.async {
                                        completion(nil, nil, error)
                                    }
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(nil, nil, error)
                        }
                    }
                }
            } else {
                apiFetcher.getFileDetail(driveId: drive.id, fileId: id) { [self] response, error in
                    if let file = response?.data {
                        keepCacheAttributesForFile(newFile: file, keepStandard: true, keepExtras: false, keepRights: false, using: realm)

                        try? realm.safeWrite {
                            realm.add(file, update: .modified)
                        }

                        let returnedFile = file.freeze()
                        DispatchQueue.main.async {
                            completion(returnedFile, [], error)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(nil, nil, error)
                        }
                    }
                }
            }
        }
    }

    public func getFavorites(page: Int = 1, sortType: SortType = .nameAZ, forceRefresh: Bool = false, completion: @escaping (File?, [File]?, Error?) -> Void) {
        apiFetcher.getFavoriteFiles(driveId: drive.id, page: page) { [self] response, error in
            if let favorites = response?.data {
                backgroundQueue.async {
                    autoreleasepool {
                        let localRealm = getRealm()
                        for favorite in favorites {
                            keepCacheAttributesForFile(newFile: favorite, keepStandard: true, keepExtras: true, keepRights: false, using: localRealm)
                        }

                        let favoritesRoot = DriveFileManager.favoriteRootFile
                        if favorites.count < DriveApiFetcher.itemPerPage {
                            favoritesRoot.fullyDownloaded = true
                        }

                        do {
                            var updatedFile: File!

                            favoritesRoot.children.append(objectsIn: favorites)
                            updatedFile = try self.updateFileInDatabase(updatedFile: favoritesRoot, using: localRealm)

                            let safeFile = ThreadSafeReference(to: updatedFile)
                            let sortedChildren = getLocalSortedDirectoryFiles(directory: updatedFile, sortType: sortType)
                            DispatchQueue.main.async {
                                completion(getRealm().resolve(safeFile), sortedChildren, nil)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                completion(nil, nil, error)
                            }
                        }
                    }
                }
            } else {
                completion(nil, nil, error)
            }
        }
    }

    public func getMyShared(page: Int = 1, sortType: SortType = .nameAZ, forceRefresh: Bool = false, completion: @escaping (File?, [File]?, Error?) -> Void) {
        apiFetcher.getMyShared(driveId: drive.id, page: page, sortType: sortType) { [self] response, error in
            let realm = getRealm()
            let mySharedRoot = DriveFileManager.mySharedRootFile
            if let sharedFiles = response?.data {
                backgroundQueue.async {
                    autoreleasepool {
                        let localRealm = getRealm()
                        for sharedFile in sharedFiles {
                            keepCacheAttributesForFile(newFile: sharedFile, keepStandard: true, keepExtras: true, keepRights: false, using: localRealm)
                        }

                        if sharedFiles.count < DriveApiFetcher.itemPerPage {
                            mySharedRoot.fullyDownloaded = true
                        }

                        do {
                            var updatedFile: File!

                            mySharedRoot.children.append(objectsIn: sharedFiles)
                            updatedFile = try self.updateFileInDatabase(updatedFile: mySharedRoot, using: localRealm)

                            let safeFile = ThreadSafeReference(to: updatedFile)
                            let sortedChildren = getLocalSortedDirectoryFiles(directory: updatedFile, sortType: sortType)
                            DispatchQueue.main.async {
                                completion(realm.resolve(safeFile), sortedChildren, nil)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                completion(nil, nil, error)
                            }
                        }
                    }
                }
            } else {
                if page == 1 {
                    if let parent = realm.object(ofType: File.self, forPrimaryKey: mySharedRoot.id) {
                        var allFiles = [File]()
                        let searchResult = parent.children.sorted(by: [sortType.value.sortDescriptor])
                        for child in searchResult.freeze() { allFiles.append(child.freeze()) }

                        mySharedRoot.fullyDownloaded = true
                        completion(mySharedRoot, allFiles, error)
                    }
                }
                completion(nil, nil, error)
            }
        }
    }

    public func getAvailableOfflineFiles(sortType: SortType = .nameAZ) -> [File] {
        let offlineFiles = getRealm().objects(File.self)
            .filter(NSPredicate(format: "isAvailableOffline = true"))
            .sorted(by: [sortType.value.sortDescriptor]).freeze()

        return offlineFiles.map { $0.freeze() }
    }

    public func getLocalSortedDirectoryFiles(directory: File, sortType: SortType) -> [File] {
        let children = directory.children.sorted(by: [
            SortDescriptor(keyPath: \File.type, ascending: true),
            SortDescriptor(keyPath: \File.rawVisibility, ascending: false),
            sortType.value.sortDescriptor
        ])

        return Array(children.freeze())
    }

    @discardableResult
    public func searchFile(query: String? = nil, date: DateInterval? = nil, fileType: String? = nil, categories: [Category], belongToAllCategories: Bool, page: Int = 1, sortType: SortType = .nameAZ, completion: @escaping (File?, [File]?, Error?) -> Void) -> DataRequest? {
        if ReachabilityListener.instance.currentStatus == .offline {
            searchOffline(query: query, date: date, fileType: fileType, categories: categories, belongToAllCategories: belongToAllCategories, sortType: sortType, completion: completion)
        } else {
            return apiFetcher.searchFiles(driveId: drive.id, query: query, date: date, fileType: fileType, categories: categories, belongToAllCategories: belongToAllCategories, page: page, sortType: sortType) { [self] response, error in
                if let files = response?.data {
                    self.backgroundQueue.async { [self] in
                        autoreleasepool {
                            let realm = getRealm()
                            let searchRoot = DriveFileManager.searchFilesRootFile
                            if files.count < DriveApiFetcher.itemPerPage {
                                searchRoot.fullyDownloaded = true
                            }
                            for file in files {
                                keepCacheAttributesForFile(newFile: file, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
                            }

                            setLocalFiles(files, root: searchRoot) {
                                let safeRoot = ThreadSafeReference(to: searchRoot)
                                let frozenFiles = files.map { $0.freeze() }
                                DispatchQueue.main.async {
                                    completion(getRealm().resolve(safeRoot), frozenFiles, nil)
                                }
                            }
                        }
                    }
                } else {
                    if error?.asAFError?.isExplicitlyCancelledError ?? false {
                        completion(nil, nil, DriveError.searchCancelled)
                    } else {
                        searchOffline(query: query, date: date, fileType: fileType, categories: categories, belongToAllCategories: belongToAllCategories, sortType: sortType, completion: completion)
                    }
                }
            }
        }
        return nil
    }

    private func searchOffline(query: String? = nil, date: DateInterval? = nil, fileType: String? = nil, categories: [Category], belongToAllCategories: Bool, sortType: SortType = .nameAZ, completion: @escaping (File?, [File]?, Error?) -> Void) {
        let realm = getRealm()
        var searchResults = realm.objects(File.self).filter("id > 0")
        if let query = query, !query.isBlank {
            searchResults = searchResults.filter(NSPredicate(format: "name CONTAINS[cd] %@", query))
        }
        if let date = date {
            searchResults = searchResults.filter(NSPredicate(format: "lastModifiedAt >= %d && lastModifiedAt <= %d", Int(date.start.timeIntervalSince1970), Int(date.end.timeIntervalSince1970)))
        }
        if let fileType = fileType {
            if fileType == ConvertedType.folder.rawValue {
                searchResults = searchResults.filter(NSPredicate(format: "type == \"dir\""))
            } else {
                searchResults = searchResults.filter(NSPredicate(format: "rawConvertedType == %@", fileType))
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

        completion(searchRoot, allFiles, DriveError.networkError)
    }

    public func getLocalFile(file: File, page: Int = 1, completion: @escaping (File?, Error?) -> Void) {
        if file.isDirectory {
            completion(nil, nil)
        } else {
            if !file.isLocalVersionOlderThanRemote() {
                // Already up to date, not downloading
                completion(file, nil)
            } else {
                DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { _, error in
                    completion(file, error)
                }
                DownloadQueue.instance.addToQueue(file: file, userId: drive.userId)
            }
        }
    }

    public func setFileAvailableOffline(file: File, available: Bool, completion: @escaping (Error?) -> Void) {
        let realm = getRealm()
        guard let file = getCachedFile(id: file.id, freeze: false, using: realm) else {
            completion(DriveError.fileNotFound)
            return
        }
        let oldUrl = file.localUrl
        let isLocalVersionOlderThanRemote = file.isLocalVersionOlderThanRemote()
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

    public func setFileShareLink(file: File, shareLink: String?) {
        updateFileProperty(fileId: file.id) { file in
            file.shareLink = shareLink
            file.rights?.canBecomeLink = shareLink == nil
        }
    }

    public func setFileCollaborativeFolder(file: File, collaborativeFolder: String?) {
        updateFileProperty(fileId: file.id) { file in
            file.collaborativeFolder = collaborativeFolder
            file.rights?.canBecomeCollab = collaborativeFolder == nil
        }
    }

    public func getLocalRecentActivities() -> [FileActivity] {
        return Array(getRealm().objects(FileActivity.self).sorted(byKeyPath: "createdAt", ascending: false).freeze())
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
                    homeRootFile.children.append(safeFile)
                    safeActivity.file = safeFile
                    if let rights = file.rights {
                        safeActivity.file?.rights = Rights(value: rights)
                    }
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

    public func setLocalFiles(_ files: [File], root: File, completion: (() -> Void)? = nil) {
        backgroundQueue.async { [self] in
            let realm = getRealm()
            for file in files {
                root.children.append(file)
                if let rights = file.rights {
                    file.rights = Rights(value: rights)
                }
            }

            try? realm.safeWrite {
                realm.add(root, update: .modified)
            }
            deleteOrphanFiles(root: root, newFiles: files, using: realm)
            completion?()
        }
    }

    public func getLastModifiedFiles(page: Int? = nil, completion: @escaping ([File]?, Error?) -> Void) {
        apiFetcher.getLastModifiedFiles(driveId: drive.id, page: page) { response, error in
            if let files = response?.data {
                self.backgroundQueue.async { [self] in
                    autoreleasepool {
                        let realm = getRealm()
                        for file in files {
                            keepCacheAttributesForFile(newFile: file, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
                        }

                        setLocalFiles(files, root: DriveFileManager.lastModificationsRootFile) {
                            let frozenFiles = files.map { $0.freeze() }
                            DispatchQueue.main.async {
                                completion(frozenFiles, nil)
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    if let files = self?.getCachedFile(id: DriveFileManager.lastModificationsRootFile.id, freeze: true)?.children {
                        completion(Array(files), error)
                    } else {
                        completion(nil, error)
                    }
                }
            }
        }
    }

    public func getLastPictures(page: Int = 1, completion: @escaping ([File]?, Error?) -> Void) {
        apiFetcher.getLastPictures(driveId: drive.id, page: page) { response, error in
            if let files = response?.data {
                self.backgroundQueue.async { [self] in
                    autoreleasepool {
                        let realm = getRealm()
                        for file in files {
                            keepCacheAttributesForFile(newFile: file, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
                        }

                        setLocalFiles(files, root: DriveFileManager.lastPicturesRootFile) {
                            let frozenFiles = files.map { $0.freeze() }
                            DispatchQueue.main.async {
                                completion(frozenFiles, nil)
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    if let files = self?.getCachedFile(id: DriveFileManager.lastPicturesRootFile.id, freeze: true)?.children {
                        completion(Array(files), error)
                    } else {
                        completion(nil, error)
                    }
                }
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

    public func getFolderActivities(file: File,
                                    date: Int? = nil,
                                    pagedActions: [Int: FileActivityType]? = nil,
                                    pagedActivities: ActivitiesResult = ActivitiesResult(),
                                    page: Int = 1,
                                    completion: @escaping (ActivitiesResult?, Int?, Error?) -> Void) {
        var pagedActions = pagedActions ?? [Int: FileActivityType]()
        let fromDate = date ?? file.responseAt
        // Using a ThreadSafeReference produced crash
        let fileId = file.id
        apiFetcher.getFileActivitiesFromDate(file: file, date: fromDate, page: page) { response, error in
            if let activities = response?.data,
               let timestamp = response?.responseAt {
                self.backgroundQueue.async { [self] in
                    let realm = getRealm()
                    guard let file = realm.object(ofType: File.self, forPrimaryKey: fileId) else {
                        DispatchQueue.main.async {
                            completion(nil, nil, nil)
                        }
                        return
                    }

                    var results = applyFolderActivitiesTo(file: file, activities: activities, pagedActions: &pagedActions, timestamp: timestamp, using: realm)
                    results.inserted.append(contentsOf: pagedActivities.inserted)
                    results.updated.append(contentsOf: pagedActivities.updated)
                    results.deleted.append(contentsOf: pagedActivities.deleted)

                    if activities.count < DriveApiFetcher.itemPerPage {
                        DispatchQueue.main.async {
                            completion(results, response?.responseAt, nil)
                        }
                    } else {
                        getFolderActivities(file: file, date: fromDate, pagedActions: pagedActions, pagedActivities: results, page: page + 1, completion: completion)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil, nil, error)
                }
            }
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func applyFolderActivitiesTo(file: File,
                                         activities: [FileActivity],
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
                       let oldParent = file.parent,
                       let index = oldParent.children.index(of: file) {
                        oldParent.children.remove(at: index)
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
                        if !file.children.contains(renamedFile) {
                            file.children.append(renamedFile)
                        }
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
                           let oldParent = file.parent,
                           let index = oldParent.children.index(of: file) {
                            oldParent.children.remove(at: index)
                        }
                        // It shouldn't be necessary to check for duplicates before adding the child
                        if !file.children.contains(newFile) {
                            file.children.append(newFile)
                        }
                        insertedFiles.append(newFile)
                        pagedActions[fileId] = .fileCreate
                    }
                case .fileFavoriteCreate, .fileFavoriteRemove, .fileUpdate, .fileShareCreate, .fileShareUpdate, .fileShareDelete, .collaborativeFolderCreate, .collaborativeFolderUpdate, .collaborativeFolderDelete, .fileColorUpdate, .fileColorDelete:
                    if let newFile = activity.file {
                        keepCacheAttributesForFile(newFile: newFile, keepStandard: true, keepExtras: true, keepRights: false, using: realm)
                        realm.add(newFile, update: .modified)
                        if !file.children.contains(newFile) {
                            file.children.append(newFile)
                        }
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

    public func getFilesActivities(driveId: Int, files: [File], from date: Int, completion: @escaping (Result<[Int: FilesActivitiesContent], Error>) -> Void) {
        apiFetcher.getFilesActivities(driveId: driveId, files: files, from: date) { response, error in
            if let error = error {
                completion(.failure(error))
            } else if let activities = response?.data?.activities {
                completion(.success(activities))
            } else {
                completion(.failure(DriveError.serverError))
            }
            // Update last sync date
            if let responseAt = response?.responseAt {
                UserDefaults.shared.lastSyncDateOfflineFiles = responseAt
            }
        }
    }

    public func getWorkingSet() -> [File] {
        // let predicate = NSPredicate(format: "isFavorite = %d OR lastModifiedAt >= %d", true, Int(Date(timeIntervalSinceNow: -3600).timeIntervalSince1970))
        let files = getRealm().objects(File.self).sorted(byKeyPath: "lastModifiedAt", ascending: false)
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
                let newCategory = FileCategory(id: categoryId, userId: self.drive.userId)
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
                if let index = file.categories.firstIndex(where: { $0.id == categoryId }) {
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
        if let drive = DriveInfosManager.instance.getDrive(objectId: self.drive.objectId, freeze: false, using: realm) {
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
            if let drive = DriveInfosManager.instance.getDrive(objectId: self.drive.objectId, freeze: false, using: realmDrive) {
                try? realmDrive.write {
                    if let index = drive.categories.firstIndex(where: { $0.id == categoryId }) {
                        drive.categories.remove(at: index)
                    }
                }
                self.drive = drive.freeze()
            }
            // Delete category from files
            let realm = getRealm()
            for file in realm.objects(File.self).filter(NSPredicate(format: "ANY categories.id = %d", categoryId)) {
                try? realm.write {
                    realm.delete(file.categories.filter("id = %d", categoryId))
                }
            }
        }
        return response
    }

    public func setFavoriteFile(file: File, favorite: Bool, completion: @escaping (Error?) -> Void) {
        let fileId = file.id
        if favorite {
            apiFetcher.postFavoriteFile(file: file) { _, error in
                if error == nil {
                    self.updateFileProperty(fileId: fileId) { file in
                        file.isFavorite = true
                    }
                }
                completion(error)
            }
        } else {
            apiFetcher.deleteFavoriteFile(file: file) { _, error in
                if error == nil {
                    self.updateFileProperty(fileId: fileId) { file in
                        file.isFavorite = false
                    }
                }
                completion(error)
            }
        }
    }

    public func delete(file: File) async throws -> CancelableResponse {
        let fileId = file.id
        let response = try await apiFetcher.delete(file: file)
        file.signalChanges(userId: self.drive.userId)
        self.backgroundQueue.async { [self] in
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
                if let index = oldParent?.children.index(of: file) {
                    oldParent?.children.remove(at: index)
                }
                newParent.children.append(file)
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

    public func renameFile(file: File, newName: String, completion: @escaping (File?, Error?) -> Void) {
        guard file.isManagedByRealm else {
            completion(nil, DriveError.fileNotFound)
            return
        }
        let safeFile = ThreadSafeReference(to: file)
        apiFetcher.renameFile(file: file, newName: newName) { [self] response, error in
            let realm = getRealm()
            if let updatedFile = response?.data,
               let file = realm.resolve(safeFile) {
                do {
                    updatedFile.isAvailableOffline = file.isAvailableOffline
                    let updatedFile = try self.updateFileInDatabase(updatedFile: updatedFile, oldFile: file, using: realm)
                    updatedFile.signalChanges(userId: drive.userId)
                    self.notifyObserversWith(file: updatedFile)
                    completion(updatedFile, nil)
                } catch {
                    completion(nil, error)
                }
            } else {
                completion(nil, error)
            }
        }
    }

    public func duplicateFile(file: File, duplicateName: String, completion: @escaping (File?, Error?) -> Void) {
        let parentId = file.parent?.id
        apiFetcher.duplicateFile(file: file, duplicateName: duplicateName) { response, error in
            if let duplicateFile = response?.data {
                do {
                    let duplicateFile = try self.updateFileInDatabase(updatedFile: duplicateFile)
                    let realm = duplicateFile.realm
                    let parent = realm?.object(ofType: File.self, forPrimaryKey: parentId)
                    try realm?.safeWrite {
                        parent?.children.append(duplicateFile)
                    }

                    duplicateFile.signalChanges(userId: self.drive.userId)
                    if let parent = file.parent {
                        parent.signalChanges(userId: self.drive.userId)
                        self.notifyObserversWith(file: parent)
                    }
                    completion(duplicateFile, nil)
                } catch {
                    completion(nil, error)
                }
            } else {
                completion(nil, error)
            }
        }
    }

    public func createDirectory(parentDirectory: File, name: String, onlyForMe: Bool, completion: @escaping (File?, Error?) -> Void) {
        let parentId = parentDirectory.id
        apiFetcher.createDirectory(parentDirectory: parentDirectory, name: name, onlyForMe: onlyForMe) { response, error in
            if let createdDirectory = response?.data {
                do {
                    let createdDirectory = try self.updateFileInDatabase(updatedFile: createdDirectory)
                    let realm = createdDirectory.realm
                    // Add directory to parent
                    let parent = realm?.object(ofType: File.self, forPrimaryKey: parentId)
                    try realm?.safeWrite {
                        parent?.children.append(createdDirectory)
                    }
                    if let parent = createdDirectory.parent {
                        parent.signalChanges(userId: self.drive.userId)
                        self.notifyObserversWith(file: parent)
                    }
                    completion(createdDirectory, error)
                } catch {
                    completion(nil, error)
                }
            } else {
                completion(nil, error)
            }
        }
    }

    public func createCommonDirectory(name: String, forAllUser: Bool, completion: @escaping (File?, Error?) -> Void) {
        apiFetcher.createCommonDirectory(driveId: drive.id, name: name, forAllUser: forAllUser) { response, error in
            if let createdDirectory = response?.data {
                do {
                    let createdDirectory = try self.updateFileInDatabase(updatedFile: createdDirectory)
                    if let parent = createdDirectory.parent {
                        parent.signalChanges(userId: self.drive.userId)
                        self.notifyObserversWith(file: parent)
                    }
                    completion(createdDirectory, error)
                } catch {
                    completion(nil, error)
                }
            } else {
                completion(nil, error)
            }
        }
    }

    // swiftlint:disable function_parameter_count
    public func createDropBox(parentDirectory: File,
                              name: String,
                              onlyForMe: Bool,
                              settings: DropBoxSettings,
                              completion: @MainActor @escaping (File?, DropBox?, Error?) -> Void) {
        let parentId = parentDirectory.id
        apiFetcher.createDirectory(parentDirectory: parentDirectory, name: name, onlyForMe: onlyForMe) { [self] response, error in
            if let createdDirectory = response?.data {
                Task {
                    do {
                        let dropbox = try await apiFetcher.createDropBox(directory: createdDirectory, settings: settings)
                        let realm = getRealm()
                        let createdDirectory = try self.updateFileInDatabase(updatedFile: createdDirectory, using: realm)

                        let parent = realm.object(ofType: File.self, forPrimaryKey: parentId)
                        try realm.write {
                            createdDirectory.collaborativeFolder = dropbox.url
                            parent?.children.append(createdDirectory)
                        }
                        if let parent = createdDirectory.parent {
                            parent.signalChanges(userId: self.drive.userId)
                            self.notifyObserversWith(file: parent)
                        }
                        await completion(createdDirectory.freeze(), dropbox, error)
                    } catch {
                        await completion(nil, nil, error)
                    }
                }
            } else {
                Task {
                    await completion(nil, nil, error)
                }
            }
        }
    }

    public func createOfficeFile(parentDirectory: File, name: String, type: String, completion: @escaping (File?, Error?) -> Void) {
        let parentId = parentDirectory.id
        apiFetcher.createOfficeFile(driveId: drive.id, parentDirectory: parentDirectory, name: name, type: type) { response, error in
            let realm = self.getRealm()
            if let file = response?.data,
               let createdFile = try? self.updateFileInDatabase(updatedFile: file, using: realm) {
                // Add file to parent
                let parent = realm.object(ofType: File.self, forPrimaryKey: parentId)
                try? realm.write {
                    parent?.children.append(createdFile)
                }
                createdFile.signalChanges(userId: self.drive.userId)

                if let parent = createdFile.parent {
                    parent.signalChanges(userId: self.drive.userId)
                    self.notifyObserversWith(file: parent)
                }

                completion(createdFile, error)
            } else {
                completion(nil, error)
            }
        }
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
        setFileShareLink(file: proxyFile, shareLink: shareLink.url)
        return shareLink
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

    private func updateFileChildrenInDatabase(file: File, using realm: Realm? = nil) throws -> File {
        let realm = realm ?? getRealm()

        if let managedFile = realm.object(ofType: File.self, forPrimaryKey: file.id) {
            try realm.write {
                file.children.insert(contentsOf: managedFile.children, at: 0)
                realm.add(file.children, update: .modified)
                realm.add(file, update: .modified)
            }
            return file
        } else {
            throw DriveError.errorWithUserInfo(.fileNotFound, info: [.fileId: ErrorUserInfo(intValue: file.id)])
        }
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
            if keepStandard {
                newFile.fullyDownloaded = savedChild.fullyDownloaded
                newFile.children = savedChild.children
                newFile.responseAt = savedChild.responseAt
            }
            if keepExtras {
                newFile.canUseTag = savedChild.canUseTag
                newFile.hasVersion = savedChild.hasVersion
                newFile.nbVersion = savedChild.nbVersion
                newFile.createdBy = savedChild.createdBy
                newFile.path = savedChild.path
                newFile.sizeWithVersion = savedChild.sizeWithVersion
                newFile.users = savedChild.users.freeze()
            }
            if keepRights {
                newFile.rights = savedChild.rights
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
        for observer in didUpdateFileObservers.values {
            observer(file.isFrozen ? file : file.freeze())
        }
    }
}
