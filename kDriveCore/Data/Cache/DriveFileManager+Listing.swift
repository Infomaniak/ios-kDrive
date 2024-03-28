/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import RealmSwift

public extension DriveFileManager {
    func fileListing(in directory: ProxyFile,
                     sortType: SortType = .nameAZ,
                     forceRefresh: Bool = false) async throws -> (files: [File], nextCursor: String?) {
        guard !directory.isRoot else {
            return try await files(in: directory, cursor: nil, sortType: sortType, forceRefresh: forceRefresh)
        }

        let lastCursor = forceRefresh ? nil : try directory.resolve(using: getRealm()).lastCursor

        let result = try await apiFetcher.files(in: directory, advancedListingCursor: lastCursor, sortType: sortType)

        let children = result.validApiResponse.data.files
        let nextCursor = result.validApiResponse.cursor
        let hasMore = result.validApiResponse.hasMore

        let realm = getRealm()
        // Keep cached properties for children
        for child in children {
            keepCacheAttributesForFile(newFile: child, keepProperties: [.standard, .extras], using: realm)
        }

        let managedParent = try directory.resolve(using: realm)

        try realm.write {
            realm.add(children, update: .modified)

            if lastCursor == nil {
                managedParent.children.removeAll()
            }
            managedParent.children.insert(objectsIn: children)

            handleActions(
                result.validApiResponse.data.actions,
                actionsFiles: result.validApiResponse.data.actionsFiles,
                directory: managedParent,
                using: realm
            )

            managedParent.lastCursor = nextCursor
            managedParent.versionCode = DriveFileManager.constants.currentVersionCode
            managedParent.fullyDownloaded = !hasMore
        }

        return (
            getLocalSortedDirectoryFiles(directory: managedParent, sortType: sortType),
            hasMore ? nextCursor : nil
        )
    }

    func handleActions(_ actions: [FileAction], actionsFiles: [File], directory: File, using realm: Realm) {
        let mappedActionsFiles = Dictionary(grouping: actionsFiles, by: \.id)
        var alreadyHandledActionIds = Set<Int>()

        // We reverse actions to handle the most recent one first
        for fileAction in actions.reversed() {
            guard let actionFile = mappedActionsFiles[fileAction.fileId]?.first,
                  !alreadyHandledActionIds.contains(fileAction.fileId) else { continue }
            alreadyHandledActionIds.insert(fileAction.fileId)

            let fileUid = File.uid(driveId: directory.driveId, fileId: fileAction.fileId)

            switch fileAction.action {
            case .fileDelete, .fileTrash:
                removeFileInDatabase(fileUid: fileUid, cascade: true, withTransaction: false, using: realm)

            case .fileMoveOut:
                guard let movedOutFile: File = realm.getObject(id: fileUid),
                      let oldParent = movedOutFile.parent else { continue }

                oldParent.children.remove(movedOutFile)
            case .fileMoveIn, .fileRestore, .fileCreate:
                keepCacheAttributesForFile(newFile: actionFile, keepProperties: [.standard, .extras], using: realm)
                realm.add(actionFile, update: .modified)

                if let existingFile: File = realm.getObject(id: fileUid),
                   let oldParent = existingFile.parent {
                    oldParent.children.remove(existingFile)
                }
                directory.children.insert(actionFile)

            case .fileRename,
                 .fileFavoriteCreate, .fileUpdate, .fileFavoriteRemove,
                 .fileShareCreate, .fileShareUpdate, .fileShareDelete,
                 .collaborativeFolderCreate, .collaborativeFolderUpdate, .collaborativeFolderDelete,
                 .fileColorUpdate, .fileColorDelete,
                 .fileCategorize, .fileUncategorize:

                if let oldFile: File = realm.getObject(id: fileUid),
                   oldFile.name != actionFile.name {
                    try? renameCachedFile(updatedFile: actionFile, oldFile: oldFile)
                }

                keepCacheAttributesForFile(newFile: actionFile, keepProperties: [.standard, .extras], using: realm)
                realm.add(actionFile, update: .modified)
                directory.children.insert(actionFile)
                actionFile.applyLastModifiedDateToLocalFile()
            default:
                break
            }
        }
    }
}
