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
import InfomaniakDI
import kDriveCore
import RealmSwift

@MainActor
class UploadCardViewModel {
    @Published var uploadCount: Int

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var uploadService: UploadQueueable

    var driveFileManager: DriveFileManager {
        didSet {
            initObservation()
        }
    }

    private var uploadDirectory: File
    private var realmObservationToken: NotificationToken?

    init(uploadDirectory: File?, driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
        self.uploadDirectory = uploadDirectory ?? driveFileManager.getCachedRootFile()
        uploadCount = 0
        initObservation()
    }

    private func initObservation() {
        let driveId = driveFileManager.driveId
        uploadCount = uploadService.getUploadingFiles(withParent: uploadDirectory.id,
                                                    userId: accountManager.currentUserId,
                                                    driveId: driveId).count
        realmObservationToken = uploadService.getUploadingFiles(withParent: uploadDirectory.id,
                                                              userId: accountManager.currentUserId,
                                                              driveId: driveId).observe(on: .main) { [weak self] change in
            switch change {
            case .initial(let results):
                self?.uploadCount = results.count
            case .update(let results, deletions: _, insertions: _, modifications: _):
                self?.uploadCount = results.count
            case .error:
                self?.uploadCount = 0
            }
        }
    }
}
