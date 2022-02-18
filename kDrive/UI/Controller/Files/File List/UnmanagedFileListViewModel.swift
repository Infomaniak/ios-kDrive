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

import Foundation
import kDriveCore

class UnmanagedFileListViewModel: FileListViewModel {
    var files: [File]
    override var isEmpty: Bool {
        return files.isEmpty
    }

    override var fileCount: Int {
        return files.count
    }

    override init(configuration: Configuration, driveFileManager: DriveFileManager, currentDirectory: File) {
        self.files = [File]()
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        driveFileManager.observeFileUpdated(self, fileId: self.currentDirectory.id) { [weak self] _ in
            // FIXME: this suboptimal, we need to improve observation
            self?.forceRefresh()
        }
    }

    required init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        fatalError("init(driveFileManager:currentDirectory:) has not been implemented")
    }

    override func sortingChanged() {
        forceRefresh()
    }

    override func getFile(at indexPath: IndexPath) -> File? {
        return indexPath.item < fileCount ? files[indexPath.item] : nil
    }

    /// Use this method to add fetched files to the file list. It will replace the list on first page and append the files on following pages.
    /// - Parameters:
    ///   - fetchedFiles: The list of files to add.
    ///   - page: The page of the files.
    final func addPage(files fetchedFiles: [File], page: Int) {
        if page == 1 {
            files = fetchedFiles
            onFileListUpdated?([], [], [], [], files.isEmpty, true)
        } else {
            let startIndex = fileCount
            files.append(contentsOf: fetchedFiles)
            onFileListUpdated?([], Array(startIndex ..< files.count), [], [], files.isEmpty, false)
        }
    }

    func removeFile(file: File) {
        if let fileIndex = files.firstIndex(where: { $0.id == file.id }) {
            files.remove(at: fileIndex)
            onFileListUpdated?([fileIndex], [], [], [], files.isEmpty, false)
        }
    }

    override func getAllFiles() -> [File] {
        return files
    }
}
