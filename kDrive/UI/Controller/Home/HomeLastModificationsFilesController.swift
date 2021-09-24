//
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

import kDriveCore
import UIKit

class HomeRecentlyModifiedFilesController: RecentFilesController {
    var currentDirectory = DriveFileManager.lastModificationsRootFile

    override func getFiles(page: Int, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        if currentDirectory.id == DriveFileManager.lastModificationsRootFile.id {
            driveFileManager.getLastModifiedFiles(page: page) { response, error in
                if let files = response {
                    completion(.success(files), files.count == DriveApiFetcher.itemPerPage, false)
                } else {
                    completion(.failure(error ?? DriveError.localError), false, false)
                }
            }
        }
    }

    override func registerCells() {
        collectionView.register(cellView: FileCollectionViewCell.self)
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: FileCollectionViewCell.self, for: indexPath)

        let file = files[indexPath.row]
        cell.initStyle(isFirst: indexPath.row == 0, isLast: indexPath.row == files.count - 1)
        cell.configureWith(file: file, selectionMode: false)

        return cell
    }
}
