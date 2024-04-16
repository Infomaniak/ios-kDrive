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
        let frozenFiles = fetchResults(ofType: File.self) { faultedCollection in
            faultedCollection.filter("isAvailableOffline = true")
                .sorted(by: [sortType.value.sortDescriptor])
                .freeze()
        }

        return frozenFiles.compactMap { !$0.isInvalidated ? $0 : nil }
    }

    func updateAvailableOfflineFiles() async throws {
        let offlineFiles = getAvailableOfflineFiles()
        guard !offlineFiles.isEmpty else { return }

        let updatedFileResult = try await getUpdatedAvailableOffline()

        try writeTransaction { writableRealm in
            for updatedFile in updatedFileResult.updatedFiles {
                updateFile(updatedFile: updatedFile, writableRealm: writableRealm)
            }

            for deletedFileUid in updatedFileResult.deletedFileUids {
                deleteOfflineFile(uid: deletedFileUid, writableRealm: writableRealm)
            }

            // After metadata update, download real files if needed
            let updatedOfflineFiles = getAvailableOfflineFiles()
            for updateOfflineFile in updatedOfflineFiles where updateOfflineFile.isLocalVersionOlderThanRemote {
                DownloadQueue.instance.addToQueue(file: updateOfflineFile, userId: drive.userId)
            }
        }
    }

    private func updateFile(updatedFile: File, writableRealm: Realm) {
        let oldFile = writableRealm.object(ofType: File.self, forPrimaryKey: updatedFile.uid)?.freeze()
        keepCacheAttributesForFile(newFile: updatedFile, keepProperties: [.standard, .extras], writableRealm: writableRealm)
        _ = try? updateFileInDatabase(updatedFile: updatedFile, oldFile: oldFile, writableRealm: writableRealm)
    }

    private func deleteOfflineFile(uid: String, writableRealm: Realm) {
        removeFileInDatabase(fileUid: uid, cascade: false, writableRealm: writableRealm)
    }
}

// FIXME: This part should be deleted once we get a better api
extension DriveFileManager {
    enum OfflineFileUpdate {
        case updated(File)
        case deleted(String)
        case error(Error)
    }

    typealias UpdatedFileResult = (updatedFiles: [File], deletedFileUids: [String])

    func getUpdatedAvailableOffline() async throws -> UpdatedFileResult {
        let offlineFiles = getAvailableOfflineFiles()

        return await withTaskGroup(of: OfflineFileUpdate.self, returning: UpdatedFileResult.self) { group in
            for file in offlineFiles {
                group.addTask { [self] in
                    do {
                        let updatedFile = try await apiFetcher.file(file)
                        if updatedFile.isTrashed {
                            return .deleted(file.uid)
                        } else {
                            return .updated(updatedFile)
                        }
                    } catch let error as DriveError where error == .objectNotFound {
                        return .deleted(file.uid)
                    } catch {
                        return .error(error)
                    }
                }
            }

            var updatedFiles = [File]()
            var deletedFiles = [String]()
            for await result in group {
                switch result {
                case .updated(let file):
                    updatedFiles.append(file)
                case .deleted(let fileUid):
                    deletedFiles.append(fileUid)
                case .error:
                    break
                }
            }

            return (updatedFiles, deletedFiles)
        }
    }
}
