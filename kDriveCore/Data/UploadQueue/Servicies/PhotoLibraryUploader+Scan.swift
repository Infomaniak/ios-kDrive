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

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            let typesPredicates = self.getAssetPredicates(forSettings: settings)
            let datePredicate = self.getDatePredicate(with: settings)
            let typePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: typesPredicates)
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, typePredicate])

            Log.photoLibraryUploader("Fetching new pictures/videos with predicate: \(options.predicate!.predicateFormat)")
            let assets = PHAsset.fetchAssets(with: options)
            let syncDate = Date()
            self.addImageAssetsToUploadQueue(assets: assets, initial: settings.lastSync.timeIntervalSince1970 == 0, using: realm)
            self.updateLastSyncDate(syncDate, using: realm)

            newAssetsCount = assets.count
            Log.photoLibraryUploader("New assets count:\(newAssetsCount)")
        }
        return newAssetsCount
    }

    // MARK: - Private

    private func updateLastSyncDate(_ date: Date) {
        updateLastSyncDate(date, using: driveUploadManager.getRealm())
    }

    private func updateLastSyncDate(_ date: Date, using realm: Realm) {
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

    private func addImageAssetsToUploadQueue(assets: PHFetchResult<PHAsset>,
                                             initial: Bool) {
        addImageAssetsToUploadQueue(assets: assets, initial: initial, using: driveUploadManager.getRealm())
    }

    private func addImageAssetsToUploadQueue(assets: PHFetchResult<PHAsset>,
                                             initial: Bool,
                                             using realm: Realm) {
        Log.photoLibraryUploader("addImageAssetsToUploadQueue")
        autoreleasepool {
            var burstIdentifier: String?
            var burstCount = 0
            realm.beginWrite()
            assets.enumerateObjects { [self] asset, idx, stop in
                guard let settings else {
                    Log.photoLibraryUploader("no settings")
                    realm.cancelWrite()
                    stop.pointee = true
                    return
                }

                @InjectService var photoLibrarySaver: PhotoLibrarySavable
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

                let bestResourceSHA256: String? = asset.bestResourceSHA256
                Log.photoLibraryUploader("Asset hash:\(bestResourceSHA256)")

                // Check if picture uploaded before
                guard !assetAlreadyUploaded(assetName: finalName,
                                            localIdentifier: asset.localIdentifier,
                                            bestResourceSHA256: bestResourceSHA256,
                                            realm: realm) else {
                    Log.photoLibraryUploader("Asset ignored because it was uploaded before")
                    return
                }

                let algorithmImportVersion = currentDiffAlgorithmVersion

                // New UploadFile to be uploaded. Priority is `.low`, first sync is `.normal`
                let uploadFile = UploadFile(
                    parentDirectoryId: settings.parentDirectoryId,
                    userId: settings.userId,
                    driveId: settings.driveId,
                    name: finalName,
                    asset: asset,
                    bestResourceSHA256: bestResourceSHA256,
                    algorithmImportVersion: algorithmImportVersion,
                    conflictOption: .version,
                    priority: initial ? .low : .normal
                )

                // Lazy creation of sub folder if required in the upload file
                if settings.createDatedSubFolders {
                    uploadFile.setDatedRelativePath()
                }

                // DB insertion
                realm.add(uploadFile, update: .modified)

                // Batching writes
                if idx < assets.count - 1 && idx % 99 == 0 {
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
        if let resource = asset.bestResource {
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

        // Only generate a different file name if has adjustments
        var modificationDate: Date?
        if #available(iOS 15, *), asset.hasAdjustments {
            modificationDate = asset.modificationDate
        }

        // Build the same name as importing manually a file
        correctName = asset.getFilename(fileExtension: fileExtension,
                                        creationDate: asset.creationDate,
                                        modificationDate: modificationDate,
                                        burstCount: burstCount,
                                        burstIdentifier: burstIdentifier)

        return correctName
    }

    /// Determines if a PHAsset was already uploaded, for a given version of it
    /// - Parameters:
    ///   - assetName: The stable name of a file
    ///   - localIdentifier: The PHAsset local identifier
    ///   - bestResourceSHA256: A hash to identify the current resource with changes if any
    ///   - realm: the realm context
    /// - Returns: True if already uploaded for a specific version of the file
    private func assetAlreadyUploaded(assetName: String,
                                      localIdentifier: String,
                                      bestResourceSHA256: String?,
                                      realm: Realm) -> Bool {
        // Roughly 10x faster than '.first(where:'
        let uploadedPictures = realm
            .objects(UploadFile.self)
            .filter(Self.uploadedAssetPredicate)

        /// Identify a PHAsset with a specific `localIdentifier` _and_ a hash, `bestResourceSHA256`, if any.
        ///
        /// Only used on iOS15 and up.
        if #available(iOS 15, *),
           uploadedPictures.filter(NSPredicate(
               format: "assetLocalIdentifier = %@ AND bestResourceSHA256 = %@",
               localIdentifier,
               bestResourceSHA256 ?? "NULL"
           ))
           .first != nil {
            Log
                .photoLibraryUploader(
                    "AlreadyUploaded match with identifier:\(localIdentifier) hash:\(String(describing: bestResourceSHA256)) "
                )
            return true
        }

        /// Legacy check only _name_ of the file that should be stable
        else if uploadedPictures.filter(NSPredicate(format: "name = %@", assetName))
            .first != nil {
            Log.photoLibraryUploader("AlreadyUploaded match with name:\(assetName)")
            return true
        }

        /// Nothing found
        else {
            return false
        }
    }

    /// Get the current diff algorithm version
    private var currentDiffAlgorithmVersion: Int {
        if #available(iOS 15, *) {
            PhotoLibraryImport.hashBestResource.rawValue
        } else {
            PhotoLibraryImport.legacyName.rawValue
        }
    }
}
