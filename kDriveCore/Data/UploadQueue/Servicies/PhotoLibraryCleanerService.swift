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
import InfomaniakDI
import Photos

public protocol PhotoLibraryCleanerServiceable {
    func hasPicturesToRemove() -> Bool
    func removePicturesScheduledForDeletion() async
}

public struct PhotoLibraryCleanerService: PhotoLibraryCleanerServiceable {
    /// Threshold value to trigger cleaning of photo roll if enabled
    static let removeAssetsCountThreshold = 10

    /// A predicate to only keep the `phAsset`
    static let photoAssetPredicate = NSPredicate(format: "rawType = %@", argumentArray: [UploadFileType.phAsset.rawValue])

    @LazyInjectService private var uploadQueue: UploadQueue

    @LazyInjectService private var photoLibraryUploader: PhotoLibraryUploader

    typealias UploadFileAssetIdentifier = (uploadFileId: String, assetIdentifierId: String)

    /// Wrapper type to map an "UploadFile" to a "PHAsset"
    struct PicturesAssets {
        /// Collection of primary keys of "UploadFile"
        public let filesPrimaryKeys: [String]

        /// collection of PHAsset
        public let assets: PHFetchResult<PHAsset>
    }

    /// Check if some pictures are scheduled for deletion
    public func hasPicturesToRemove() -> Bool {
        var hasPicturesToRemove = false
        BackgroundRealm.uploads.execute { realm in
            let uploadFilesToCleanCount = uploadQueue
                .getUploadedFiles(using: realm)
                .filter(Self.photoAssetPredicate)
                .count

            hasPicturesToRemove = uploadFilesToCleanCount > 0
        }

        return hasPicturesToRemove
    }

    /// Batch cleanup of pictures scheduled for deletion
    public func removePicturesScheduledForDeletion() async {
        guard let picturesToRemove = getPicturesToRemove() else {
            Log.photoLibraryUploader("no pictures to remove")
            return
        }

        removePicturesFromPhotoLibrary(picturesToRemove)
    }

    private func getPicturesToRemove() -> PicturesAssets? {
        Log.photoLibraryUploader("getPicturesToRemove")
        // Check that we have photo sync enabled with the delete option
        guard let settings = photoLibraryUploader.settings, settings.deleteAssetsAfterImport else {
            Log.photoLibraryUploader("no settings")
            return nil
        }

        var assetsToRemove = [UploadFileAssetIdentifier]()
        BackgroundRealm.uploads.execute { realm in
            let uploadFilesToClean = uploadQueue
                .getUploadedFiles(using: realm)
                .filter(Self.photoAssetPredicate)

            assetsToRemove = uploadFilesToClean.compactMap { uploadFile in
                guard let assetIdentifier = uploadFile.assetLocalIdentifier else {
                    return nil
                }

                return (uploadFile.id, assetIdentifier)
            }
        }

        let allUploadFileIds = assetsToRemove.map(\.uploadFileId)
        let allAssetsIds = assetsToRemove.map(\.assetIdentifierId)

        let toRemoveAssetsFetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: allAssetsIds,
            options: nil
        )

        guard assetsToRemove.count >= Self.removeAssetsCountThreshold,
              uploadQueue.operationQueue.operationCount == 0 else {
            return nil
        }

        return PicturesAssets(filesPrimaryKeys: allUploadFileIds, assets: toRemoveAssetsFetchResult)
    }

    private func removePicturesFromPhotoLibrary(_ toRemoveItems: PicturesAssets) {
        Log.photoLibraryUploader("removePicturesFromPhotoLibrary toRemoveItems:\(toRemoveItems.filesPrimaryKeys.count)")
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(toRemoveItems.assets)
        } completionHandler: { success, _ in
            guard success else {
                return
            }

            BackgroundRealm.uploads.execute { realm in
                do {
                    try realm.write {
                        let filesInContext = realm
                            .objects(UploadFile.self)
                            .filter("id IN %@", toRemoveItems.filesPrimaryKeys)
                            .filter { $0.isInvalidated == false }
                        realm.delete(filesInContext)
                    }
                    Log.photoLibraryUploader("removePicturesFromPhotoLibrary success", level: .info)
                } catch {
                    Log.photoLibraryUploader("removePicturesFromPhotoLibrary error:\(error)", level: .error)
                }
            }
        }
    }
}
