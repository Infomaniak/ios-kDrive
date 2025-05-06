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
import RealmSwift

public extension PhotoLibraryUploader {
    @MainActor func enableSync(_ liveNewSyncSettings: PhotoSyncSettings) {
        let currentSyncSettings = frozenSettings
        try? uploadsDatabase.writeTransaction { writableRealm in
            guard liveNewSyncSettings.userId != -1,
                  liveNewSyncSettings.driveId != -1,
                  liveNewSyncSettings.parentDirectoryId != -1 else {
                return
            }

            switch liveNewSyncSettings.syncMode {
            case .new:
                liveNewSyncSettings.lastSync = Date()
            case .all:
                if let currentSyncSettings,
                   currentSyncSettings.syncMode == .all {
                    liveNewSyncSettings.lastSync = currentSyncSettings.lastSync
                } else {
                    liveNewSyncSettings.lastSync = Date(timeIntervalSince1970: 0)
                }
            case .fromDate:
                if let currentSyncSettings = currentSyncSettings,
                   currentSyncSettings
                   .syncMode == .all ||
                   (currentSyncSettings.syncMode == .fromDate && currentSyncSettings.fromDate
                       .compare(liveNewSyncSettings.fromDate) == .orderedAscending) {
                    liveNewSyncSettings.lastSync = currentSyncSettings.lastSync
                } else {
                    liveNewSyncSettings.lastSync = liveNewSyncSettings.fromDate
                }
            }

            writableRealm.add(liveNewSyncSettings, update: .all)
        }
    }

    func disableSync() {
        try? uploadsDatabase.writeTransaction { writableRealm in
            writableRealm.delete(writableRealm.objects(PhotoSyncSettings.self))
        }
        
        Task {
            do {
                try await uploadsService.cancelAnyPhotoSync()
            }
            catch {
                Log.photoLibraryUploader("Failed to cancel all uploads: \(error)", level: .error)
            }
        }
    }
}
