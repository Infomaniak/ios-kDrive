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

class HomePhotoListController: HomeRecentFilesController {
    override var emptyCellType: EmptyTableView.EmptyTableViewType {
        return .noImages
    }

    override func loadNextPage(forceRefresh: Bool = false) {
        guard !loading && moreComing else {
            return
        }

        driveFileManager.getLastPictures(page: page) { response, _ in
            if let files = response {
                self.empty = self.page == 1 && files.isEmpty
                DispatchQueue.main.async {
                    self.homeViewController?.reloadWith(fetchedFiles: files, isEmpty: self.empty)
                }
                self.page += 1
                self.moreComing = files.count == DriveApiFetcher.itemPerPage
            }
            self.loading = false
        }
    }
}
