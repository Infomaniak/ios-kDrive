/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import RealmSwift

public extension DriveFileManager {
    func getAvailableOfflineFiles(sortType: SortType = .nameAZ) -> [File] {
        let frozenFiles = database.fetchResults(ofType: File.self) { lazyCollection in
            lazyCollection
                .filter("isAvailableOffline = true")
                .sorted(by: [sortType.value.sortDescriptor])
                .freeze()
        }

        return Array(frozenFiles)
    }

    func updateAvailableOfflineFiles() async throws {
        let offlineFiles = getAvailableOfflineFiles()
        guard !offlineFiles.isEmpty else { return }

        let batchSize = 500
        for i in stride(from: 0, through: offlineFiles.count - 1, by: batchSize) {
            let batchFiles = Array(offlineFiles.dropFirst(i).prefix(batchSize))
            let batchActivities = try await apiFetcher.filesLastActivities(files: batchFiles, drive: drive)

            var updatedFiles = [File]()
            try database.writeTransaction { writableRealm in
                for activity in batchActivities {
                    if let file = activity.file,
                       [FileActivityType.fileUpdate, FileActivityType.fileRename].contains(activity.lastAction) {
                        updateFile(updatedFile: file, lastActionAt: activity.lastActionAt, writableRealm: writableRealm)
                        updatedFiles.append(file)
                    } else if [FileActivityType.fileDelete, FileActivityType.fileTrash].contains(activity.lastAction) {
                        removeFileInDatabase(
                            fileUid: File.uid(driveId: drive.id, fileId: activity.fileId),
                            cascade: false,
                            writableRealm: writableRealm
                        )
                    }
                }
            }

            for updatedFile in updatedFiles where updatedFile.isLocalVersionOlderThanRemote {
                DownloadQueue.instance.addToQueue(file: updatedFile, userId: drive.userId)
            }
        }
    }

    private func updateFile(updatedFile: File, lastActionAt: Int?, writableRealm: Realm) {
        let oldFile = writableRealm.object(ofType: File.self, forPrimaryKey: updatedFile.uid)?.freeze()
        keepCacheAttributesForFile(newFile: updatedFile, keepProperties: [.all], writableRealm: writableRealm)
        if let lastActionAt {
            updatedFile.lastActionAt = lastActionAt
        }
        _ = try? updateFileInDatabase(updatedFile: updatedFile, oldFile: oldFile, writableRealm: writableRealm)
    }

    private func deleteOfflineFile(uid: String, writableRealm: Realm) {
        removeFileInDatabase(fileUid: uid, cascade: false, writableRealm: writableRealm)
    }
}
