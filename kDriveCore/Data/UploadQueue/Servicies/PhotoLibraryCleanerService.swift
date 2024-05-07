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

/// Something that handle the cleaning post upload of pictures in Photo.app
public protocol PhotoLibraryCleanerServiceable {
    /// Check if some pictures are scheduled for deletion
    var hasPicturesToRemove: Bool { get }

    /// Async cleanup of pictures scheduled for deletion
    func removePicturesScheduledForDeletion() async
}

/// Tuple linking an UploadFile id to a PHAssetLocalIdentifier
typealias UploadFileAssetIdentifier = (uploadFileId: String, localAssetIdentifier: String)

public struct PhotoLibraryCleanerService: PhotoLibraryCleanerServiceable {
    /// Threshold value to trigger cleaning of photo roll if enabled
    static let removeAssetsCountThreshold = 10

    /// A predicate to only keep the `phAsset`
    static let photoAssetPredicate = NSPredicate(format: "rawType = %@", argumentArray: [UploadFileType.phAsset.rawValue])

    @LazyInjectService private var uploadQueue: UploadQueue

    @LazyInjectService private var photoLibraryUploader: PhotoLibraryUploader

    /// `True` if feature setting is ON
    private var removePictureEnabled: Bool {
        // Check that we have photo sync enabled with the delete option
        guard let settings = photoLibraryUploader.settings, settings.deleteAssetsAfterImport else {
            Log.photoLibraryUploader("remove picture feature disabled")
            return false
        }
        return true
    }

    public var hasPicturesToRemove: Bool {
        guard removePictureEnabled else {
            Log.photoLibraryUploader("RemovePicture feature not Enabled in settings")
            return false
        }

        // TODO: Use transactionable directly
        var picturesToRemoveCount = 0
        BackgroundRealm.uploads.execute { writableRealm in
            picturesToRemoveCount = uploadQueue
                .getUploadedFiles(using: writableRealm)
                .filter(Self.photoAssetPredicate)
                .count
        }

        guard picturesToRemoveCount >= Self.removeAssetsCountThreshold else {
            Log.photoLibraryUploader("Not enough pictures to delete, skipping")
            return false
        }

        guard uploadQueue.operationQueue.operationCount == 0 else {
            Log.photoLibraryUploader("Uploads underway, skipping")
            return false
        }

        return true
    }

    public func removePicturesScheduledForDeletion() async {
        guard removePictureEnabled else {
            return
        }

        guard let picturesToRemove = getPicturesToRemove() else {
            Log.photoLibraryUploader("no pictures to remove")
            return
        }

        removePicturesFromPhotoLibrary(picturesToRemove)
    }

    private func getPicturesToRemove() -> [UploadFileAssetIdentifier]? {
        Log.photoLibraryUploader("getPicturesToRemove")

        // TODO: Use transactionable directly
        var assetsToRemove = [UploadFileAssetIdentifier]()
        BackgroundRealm.uploads.execute { writableRealm in
            let uploadFilesToClean = uploadQueue
                .getUploadedFiles(using: writableRealm)
                .filter(Self.photoAssetPredicate)

            assetsToRemove = uploadFilesToClean.compactMap { uploadFile in
                guard let assetIdentifier = uploadFile.assetLocalIdentifier else {
                    return nil
                }

                return (uploadFile.id, assetIdentifier)
            }
        }

        return assetsToRemove
    }

    private func removePicturesFromPhotoLibrary(_ itemsIdentifiers: [UploadFileAssetIdentifier]) {
        Log.photoLibraryUploader("removePicturesFromPhotoLibrary :\(itemsIdentifiers.count)")

        let allAssetIdentifiers = itemsIdentifiers.map(\.localAssetIdentifier)
        let allAssetFetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: allAssetIdentifiers,
            options: nil
        )

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(allAssetFetchResult)
        } completionHandler: { success, error in
            guard success else {
                Log.photoLibraryUploader(
                    "removePicturesFromPhotoLibrary performChanges error:\(String(describing: error))",
                    level: .error
                )
                return
            }

            // TODO: Use transactionable directly
            BackgroundRealm.uploads.execute { writableRealm in
                let allUploadFileIds = itemsIdentifiers.map(\.uploadFileId)
                do {
                    let filesInContext = writableRealm
                        .objects(UploadFile.self)
                        .filter("id IN %@", allUploadFileIds)
                        .filter { $0.isInvalidated == false }
                    writableRealm.delete(filesInContext)
                    Log.photoLibraryUploader("removePicturesFromPhotoLibrary success")
                } catch {
                    Log.photoLibraryUploader("removePicturesFromPhotoLibrary BackgroundRealm error:\(error)",
                                             level: .error)
                }
            }
        }
    }
}
