/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

/// Categorizes the file actions returned by the advanced listing endpoint so the File Provider
/// knows which items to update, delete or simply remove from the enumerated directory.
///
/// The API can return several actions for the same file within a single page. Only the most recent
/// action per file is kept so the File Provider reflects the final state of each file.
public struct FileProviderActionsReducer {
    /// The files grouped by the effect their most recent action has on the directory.
    ///
    /// The three sets are mutually exclusive: a given file id can only appear in one of them.
    public struct Output {
        /// Files that should be updated in / inserted into the directory.
        public let updated: Set<File>
        /// Ids of files that were deleted, trashed or are no longer accessible and must be removed from the cache.
        public let deletedFileIds: Set<Int>
        /// Ids of files that were moved out of the directory. They must be removed from the directory
        /// but kept in the cache since they still exist somewhere else.
        public let movedOutFileIds: Set<Int>
    }

    public init() {}

    public func reduce(actions: [FileAction], actionsFiles: [File]) -> Output {
        let mappedActionsFiles = Dictionary(grouping: actionsFiles, by: \.id)
        var alreadyHandledActionIds = Set<Int>()

        var deletedFileIds = Set<Int>()
        var movedOutFileIds = Set<Int>()
        var updatedFiles = Set<File>()

        // We reverse actions to handle the most recent one first
        for fileAction in actions.reversed() {
            guard alreadyHandledActionIds.insert(fileAction.fileId).inserted else { continue }

            switch fileAction.action {
            case .fileDelete, .fileTrash:
                deletedFileIds.insert(fileAction.fileId)
            case .fileMoveOut:
                movedOutFileIds.insert(fileAction.fileId)
            case .fileRename, .fileMoveIn, .fileRestore, .fileCreate, .fileFavoriteCreate, .fileFavoriteRemove, .fileUpdate,
                 .fileShareCreate, .fileShareUpdate, .fileShareDelete, .collaborativeFolderCreate, .collaborativeFolderUpdate,
                 .collaborativeFolderDelete, .fileColorUpdate, .fileColorDelete:
                if let actionFile = mappedActionsFiles[fileAction.fileId]?.first {
                    updatedFiles.insert(actionFile)
                } else {
                    deletedFileIds.insert(fileAction.fileId)
                }
            default:
                break
            }
        }

        return Output(
            updated: updatedFiles,
            deletedFileIds: deletedFileIds,
            movedOutFileIds: movedOutFileIds
        )
    }
}
