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
import InfomaniakCore
import InfomaniakDI
import Photos
import RealmSwift

public extension PhotoLibraryUploader {
    @discardableResult
    func scheduleNewPicturesForUpload() -> Int {
        var newAssetsCount = 0
        BackgroundRealm.uploads.execute { realm in
            Log.photoLibraryUploader("scheduleNewPicturesForUpload")
            guard let settings = self.settings,
                  PHPhotoLibrary.authorizationStatus() == .authorized else {
                Log.photoLibraryUploader("0 new assets")
                return
            }

            let initialUpload = settings.lastSync.timeIntervalSince1970 == 0

            // Loading main photo assets
            let mainFetchResult = mainAssetsFetchResult(settings)
            let syncDate = Date()

            defer {
                updateLastSyncDate(syncDate, using: realm)
                Log.photoLibraryUploader("New assets count:\(newAssetsCount)")
            }

            addAssetsToUploadQueue(mainFetchResult, initial: initialUpload, using: realm)
            newAssetsCount += mainFetchResult.count

            // Check sync state for the local albums
            guard settings.syncLocalAlbumsEnabled else {
                return
            }

            // Load assets form user defined albums
            let albumsFetchResult = userLibrariesFetchResult(settings)
            albumsFetchResult.enumerateObjects { collection, index, object in
                guard let collection = collection as? PHAssetCollection else {
                    return
                }

                let albumName = collection.localizedTitle
                let options = self.albumsRollQueryOptions(settings)
                let fetchedAlbumAssets = PHAsset.fetchAssets(in: collection, options: options)
                Log.photoLibraryUploader("New assets (\(fetchedAlbumAssets.count) in album :\(albumName)")
                self.addAssetsToUploadQueue(fetchedAlbumAssets,
                                            albumName: albumName,
                                            initial: initialUpload,
                                            using: realm)
                newAssetsCount += fetchedAlbumAssets.count
            }
        }
        return newAssetsCount
    }

    private func updateLastSyncDate(_ date: Date, using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        if let settings = realm.objects(PhotoSyncSettings.self).first {
            try? realm.safeWrite {
                if !settings.isInvalidated {
                    settings.lastSync = date
                }
            }
            if settings.isInvalidated {
                _settings = nil
            } else {
                _settings = PhotoSyncSettings(value: settings)
            }
        }
    }

    private func addAssetsToUploadQueue(_ fetchResult: PHFetchResult<PHAsset>,
                                        albumName: String? = nil,
                                        initial: Bool,
                                        using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        Log.photoLibraryUploader("addImageAssetsToUploadQueue")
        autoreleasepool {
            var burstIdentifier: String?
            var burstCount = 0
            realm.beginWrite()
            fetchResult.enumerateObjects { [self] asset, idx, stop in
                guard let settings else {
                    Log.photoLibraryUploader("no settings")
                    realm.cancelWrite()
                    stop.pointee = true
                    return
                }

                if let assetCollectionIdentifier = photoLibrarySaver.assetCollection?.localIdentifier {
                    let options = PHFetchOptions()
                    options.predicate = NSPredicate(format: "localIdentifier = %@", assetCollectionIdentifier)
                    let assetCollections = PHAssetCollection.fetchAssetCollectionsContaining(
                        asset,
                        with: .album,
                        options: options
                    )
                    // swiftlint:disable:next empty_count
                    if assetCollections.count > 0 {
                        Log.photoLibraryUploader("Asset ignored because it already originates from kDrive")
                        return
                    }
                }

                // Get a unique file identifier while taking care of the burst state
                let finalName = getPhotoLibraryName(
                    forAsset: asset,
                    settings: settings,
                    burstIdentifier: &burstIdentifier,
                    burstCount: &burstCount
                )

                // Check if picture uploaded before
                guard !assetAlreadyUploaded(assetName: finalName, realm: realm) else {
                    Log.photoLibraryUploader("Asset ignored because it was uploaded before")
                    return
                }

                // Store a new upload file in base
                let uploadFile = UploadFile(
                    parentDirectoryId: settings.parentDirectoryId,
                    userId: settings.userId,
                    driveId: settings.driveId,
                    name: finalName,
                    asset: asset,
                    conflictOption: .version,
                    priority: initial ? .low : .high
                )

                if settings.syncLocalAlbumsEnabled, let albumName {
                    uploadFile.setAlbumRelativePath(name: albumName)
                } else if settings.createDatedSubFolders {
                    uploadFile.setDatedRelativePath()
                }

                realm.add(uploadFile, update: .modified)

                if idx < fetchResult.count - 1 && idx % 99 == 0 {
                    Log.photoLibraryUploader("Commit assets batch up to :\(idx)")
                    // Commit write every 100 assets if it's not the last
                    try? realm.commitWrite()
                    if let creationDate = asset.creationDate {
                        updateLastSyncDate(creationDate, using: realm)
                    }

                    realm.beginWrite()
                }
            }
            try? realm.commitWrite()
        }
    }

    private func getPhotoLibraryName(
        forAsset asset: PHAsset,
        settings: PhotoSyncSettings,
        burstIdentifier: inout String?,
        burstCount: inout Int
    ) -> String {
        let correctName: String
        let fileExtension: String

        // build fileExtension
        if let resource = asset.bestResource() {
            if resource.uniformTypeIdentifier == UTI.heic.identifier,
               let preferredFilenameExtension = settings.photoFormat.uti.preferredFilenameExtension {
                fileExtension = preferredFilenameExtension
            } else {
                fileExtension = UTI(resource.uniformTypeIdentifier)?.preferredFilenameExtension
                    ?? (resource.originalFilename as NSString).pathExtension
            }
        } else {
            fileExtension = ""
        }

        // Compute index of burst photos
        if burstIdentifier != nil && burstIdentifier == asset.burstIdentifier {
            burstCount += 1
        } else {
            burstCount = 0
        }
        burstIdentifier = asset.burstIdentifier

        // Build the same name as importing manually a file
        correctName = asset.getFilename(fileExtension: fileExtension,
                                        creationDate: asset.creationDate,
                                        burstCount: burstCount,
                                        burstIdentifier: burstIdentifier)

        return correctName
    }

    private func assetAlreadyUploaded(assetName: String, realm: Realm) -> Bool {
        // Roughly 10x faster than '.first(where:'
        guard realm
            .objects(UploadFile.self)
            .filter(Self.uploadedAssetPredicate)
            .filter(NSPredicate(format: "name = %@", assetName))
            .first != nil else {
            return false
        }

        return true
    }
}
