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
import kDriveCore

final class PublicShareSingleFileViewModel: PublicShareViewModel {
    override init(configuration: Configuration, driveFileManager: DriveFileManager, currentDirectory: File) {
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        title = currentDirectory.name
    }

    required init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        fatalError("Use init(publicShareProxy:… ) instead")
    }

    // No refresh for single file
    override func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        endRefreshing()
    }
}
