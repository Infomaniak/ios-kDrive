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
import InfomaniakDI
import RealmSwift

public protocol PhotoLibrarySyncable {
    @MainActor func enableSync(_ liveNewSyncSettings: PhotoSyncSettings)
    func disableSync()
}

extension PhotoLibraryUploader: PhotoLibrarySyncable {
    @MainActor public func enableSync(_ liveNewSyncSettings: PhotoSyncSettings) {
        let currentSyncSettings = frozenSettings
        let shouldReset = (currentSyncSettings?.driveId != liveNewSyncSettings.driveId)
            || (currentSyncSettings?.userId != liveNewSyncSettings.userId)
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
                   currentSyncSettings.syncMode == .all,
                   !shouldReset {
                    liveNewSyncSettings.lastSync = currentSyncSettings.lastSync
                } else {
                    liveNewSyncSettings.lastSync = Date(timeIntervalSince1970: 0)
                }
            case .fromDate:
                if let currentSyncSettings = currentSyncSettings,
                   currentSyncSettings
                   .syncMode == .all ||
                   (currentSyncSettings.syncMode == .fromDate && currentSyncSettings.fromDate
                       .compare(liveNewSyncSettings.fromDate) == .orderedAscending),
                   !shouldReset {
                    liveNewSyncSettings.lastSync = currentSyncSettings.lastSync
                } else {
                    liveNewSyncSettings.lastSync = liveNewSyncSettings.fromDate
                }
            }

            writableRealm.add(liveNewSyncSettings, update: .all)
        }

        guard shouldReset else { return }

        let parentDirectoryId = liveNewSyncSettings.parentDirectoryId
        let userId = liveNewSyncSettings.userId
        let driveId = liveNewSyncSettings.driveId

        Task {
            await postSaveSettings(
                shouldReset: shouldReset,
                parentDirectoryId: parentDirectoryId,
                userId: userId,
                driveId: driveId
            )
        }
    }

    private func postSaveSettings(shouldReset: Bool, parentDirectoryId: Int, userId: Int, driveId: Int) async {
        @InjectService var photoLibraryScan: PhotoLibraryScanable
        await photoLibraryScan.cancelScan()

        if shouldReset {
            try? await uploadService.cancelAnyPhotoSync()
            await forgetUploadedPhotos()
        }

        uploadService.retryAllOperations(
            withParent: parentDirectoryId,
            userId: userId,
            driveId: driveId
        )
        uploadService.updateQueueSuspension()

        photoLibraryScan.scheduleNewPicturesForUpload()
        uploadService.rebuildUploadQueue()
    }

    public func disableSync() {
        try? uploadsDatabase.writeTransaction { writableRealm in
            writableRealm.delete(writableRealm.objects(PhotoSyncSettings.self))
        }

        Task {
            @InjectService var photoLibraryScan: PhotoLibraryScanable
            await photoLibraryScan.cancelScan()

            do {
                try await uploadService.cancelAnyPhotoSync()
                await forgetUploadedPhotos()
            } catch {
                Log.photoLibraryUploader("Failed to clear photo sync queue: \(error)", level: .error)
            }
        }
    }

    public func forgetUploadedPhotos() async {
        @InjectService var uploadDataSource: UploadServiceDataSourceable

        let objectsIdsToDelete = uploadDataSource
            .getUploadedFilesIDs(optionalPredicate: PhotoLibraryCleanerService.photoAssetPredicate)
        let chunks = objectsIdsToDelete.chunks(ofCount: 50)

        try? chunks.forEach { chunk in
            try self.uploadsDatabase.writeTransaction { writableRealm in
                for uploadFileId in chunk {
                    guard let objectToRemove = writableRealm.object(ofType: UploadFile.self, forPrimaryKey: uploadFileId) else {
                        continue
                    }
                    writableRealm.delete(objectToRemove)
                }
            }
        }
    }
}
