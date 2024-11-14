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

        let lastCursor = forceRefresh ? nil : try directory.resolve(within: self).lastCursor

        let result = try await apiFetcher.files(in: directory, advancedListingCursor: lastCursor, sortType: sortType)

        let children = result.validApiResponse.data.files
        let nextCursor = result.validApiResponse.cursor
        let responseAt = result.validApiResponse.responseAt
        let hasMore = result.validApiResponse.hasMore

        var managedParentDirectory: File?
        try database.writeTransaction { writableRealm in
            // Keep cached properties for children
            for child in children {
                keepCacheAttributesForFile(newFile: child, keepProperties: [.standard, .extras], writableRealm: writableRealm)
            }

            let managedParent = try directory.resolve(using: writableRealm)
            managedParentDirectory = managedParent

            writableRealm.add(children, update: .modified)

            if lastCursor == nil {
                managedParent.children.removeAll()
            }
            managedParent.children.insert(objectsIn: children)

            handleActions(
                result.validApiResponse.data.actions,
                actionsFiles: result.validApiResponse.data.actionsFiles,
                directory: managedParent,
                writableRealm: writableRealm
            )

            // post `handleActions` managedParent may be invalidated in current context
            guard !managedParent.isInvalidated else {
                return
            }

            managedParent.lastCursor = nextCursor
            managedParent.versionCode = DriveFileManager.constants.currentVersionCode
            managedParent.fullyDownloaded = !hasMore
            managedParent.responseAt = responseAt ?? Int(Date().timeIntervalSince1970)
        }

        guard let managedParentDirectory else {
            throw DriveError.fileNotFound
        }

        let resultCursor = hasMore ? nextCursor : nil
        let resultFiles = getLocalSortedDirectoryFiles(directory: managedParentDirectory, sortType: sortType)
        return (resultFiles, resultCursor)
    }

    func handleActions(_ actions: [FileAction], actionsFiles: [File], directory: File, writableRealm: Realm) {
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
                removeFileInDatabase(fileUid: fileUid, cascade: true, writableRealm: writableRealm)

            case .fileMoveOut:
                guard let movedOutFile: File = writableRealm.getObject(id: fileUid),
                      let oldParent = movedOutFile.parent else { continue }

                oldParent.children.remove(movedOutFile)

            case .fileMoveIn, .fileRestore, .fileCreate:
                keepCacheAttributesForFile(
                    newFile: actionFile,
                    keepProperties: [.standard, .extras],
                    writableRealm: writableRealm
                )
                writableRealm.add(actionFile, update: .modified)

                if let existingFile: File = writableRealm.getObject(id: fileUid),
                   let oldParent = existingFile.parent {
                    oldParent.children.remove(existingFile)
                }

                if fileUid != directory.uid {
                    directory.children.insert(actionFile)
                }

            case .fileRename,
                 .fileFavoriteCreate, .fileUpdate, .fileFavoriteRemove,
                 .fileShareCreate, .fileShareUpdate, .fileShareDelete,
                 .collaborativeFolderCreate, .collaborativeFolderUpdate, .collaborativeFolderDelete,
                 .fileColorUpdate, .fileColorDelete,
                 .fileCategorize, .fileUncategorize:

                if let oldFile: File = writableRealm.getObject(id: fileUid),
                   oldFile.name != actionFile.name {
                    try? renameCachedFile(updatedFile: actionFile, oldFile: oldFile)
                }

                keepCacheAttributesForFile(
                    newFile: actionFile,
                    keepProperties: [.standard, .extras],
                    writableRealm: writableRealm
                )
                writableRealm.add(actionFile, update: .modified)

                if fileUid != directory.uid {
                    directory.children.insert(actionFile)
                }

            default:
                break
            }
        }
    }
}
