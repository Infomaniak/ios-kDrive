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

class HomeRecentFilesController {
    let driveFileManager: DriveFileManager
    weak var homeViewController: HomeViewController?

    var listStyle: ListStyle = .list
    var displayedFiles = [File]()
    var fetchedFiles: [File]?
    var page = 1
    var loading = false
    var moreComing = false

    init(driveFileManager: DriveFileManager, homeViewController: HomeViewController) {
        self.driveFileManager = driveFileManager
        self.homeViewController = homeViewController
        homeViewController.reload()
        loadFiles()
    }

    func loadFiles(forceRefresh: Bool = false) {
        guard !loading || moreComing else {
            return
        }

        loading = true
    }
}
