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

import CocoaLumberjackSwift
import Foundation
import InfomaniakDI
import Photos
import RealmSwift
import Sentry

public class PhotoLibraryUploader {
    @LazyInjectService var uploadQueue: UploadQueue

    /// Threshold value to trigger cleaning of photo roll if enabled
    static let removeAssetsCountThreshold = 10

    /// Predicate to quickly narrow down on uploaded assets
    static let uploadedAssetPredicate = NSPredicate(format: "rawType = %@ AND uploadDate != nil", "phAsset")

    private let dateFormatter = DateFormatter()

    public private(set) var settings: PhotoSyncSettings?
    public var isSyncEnabled: Bool {
        return settings != nil
    }

    public init() {
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss_SSSS"

        if let settings = DriveFileManager.constants.uploadsRealm.objects(PhotoSyncSettings.self).first {
            self.settings = PhotoSyncSettings(value: settings)
        }
    }

    public func enableSync(with newSettings: PhotoSyncSettings, using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        try? realm.write {
            realm.delete(realm.objects(PhotoSyncSettings.self))
            realm.add(newSettings)
        }
        settings = PhotoSyncSettings(value: newSettings)
    }

    public func disableSync(using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        try? realm.safeWrite {
            realm.delete(realm.objects(PhotoSyncSettings.self))
        }
        settings = nil
    }

    private func updateLastSyncDate(_ date: Date, using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        if let settings = realm.objects(PhotoSyncSettings.self).first {
            try? realm.safeWrite {
                if !settings.isInvalidated {
                    settings.lastSync = date
                }
            }
            if settings.isInvalidated {
                self.settings = nil
            } else {
                self.settings = PhotoSyncSettings(value: settings)
            }
        }
    }

    func getUrl(for asset: PHAsset) async -> URL? {
        return await asset.getUrl(preferJPEGFormat: settings?.photoFormat == .jpg)
    }

    @discardableResult
    public func scheduleNewPicturesForUpload() -> Int {
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
            // Create predicate from settings
            var typesPredicates = [NSPredicate]()
            if settings.syncPicturesEnabled && settings.syncScreenshotsEnabled {
                typesPredicates.append(NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue))
            } else if settings.syncPicturesEnabled {
                typesPredicates.append(NSPredicate(
                    format: "(mediaType == %d) AND !((mediaSubtype & %d) == %d)",
                    PHAssetMediaType.image.rawValue,
                    PHAssetMediaSubtype.photoScreenshot.rawValue,
                    PHAssetMediaSubtype.photoScreenshot.rawValue
                ))
            } else if settings.syncScreenshotsEnabled {
                typesPredicates.append(NSPredicate(
                    format: "(mediaType == %d) AND ((mediaSubtype & %d) == %d)",
                    PHAssetMediaType.image.rawValue,
                    PHAssetMediaSubtype.photoScreenshot.rawValue,
                    PHAssetMediaSubtype.photoScreenshot.rawValue
                ))
            }
            if settings.syncVideosEnabled {
                typesPredicates.append(NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue))
            }
            let datePredicate = NSPredicate(format: "creationDate > %@", settings.lastSync as NSDate)
            let typePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: typesPredicates)
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, typePredicate])

            Log.photoLibraryUploader("Fetching new pictures/videos with predicate: \(options.predicate!.predicateFormat)")
            let assets = PHAsset.fetchAssets(with: options)
            let syncDate = Date()
            addImageAssetsToUploadQueue(assets: assets, initial: settings.lastSync.timeIntervalSince1970 == 0, using: realm)
            updateLastSyncDate(syncDate, using: realm)

            newAssetsCount = assets.count
            Log.photoLibraryUploader("New assets count:\(newAssetsCount)")
        }
        return newAssetsCount
    }

    private func addImageAssetsToUploadQueue(assets: PHFetchResult<PHAsset>,
                                             initial: Bool,
                                             using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        Log.photoLibraryUploader("addImageAssetsToUploadQueue")
        autoreleasepool {
            var burstIdentifier: String?
            var burstCount = 0
            realm.beginWrite()
            assets.enumerateObjects { [self] asset, idx, stop in
                guard let settings = settings else {
                    Log.photoLibraryUploader("no settings")
                    realm.cancelWrite()
                    stop.pointee = true
                    return
                }
                if let assetCollectionIdentifier = PhotoLibrarySaver.instance.assetCollection?.localIdentifier {
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
                var correctName = "No-name-\(Date().timeIntervalSince1970)"
                var fileExtension = ""
                if let resource = asset.bestResource() {
                    if resource.uniformTypeIdentifier == UTI.heic.identifier,
                       let preferredFilenameExtension = settings.photoFormat.uti.preferredFilenameExtension {
                        fileExtension = preferredFilenameExtension
                    } else {
                        fileExtension = UTI(resource.uniformTypeIdentifier)?.preferredFilenameExtension
                            ?? (resource.originalFilename as NSString).pathExtension
                    }
                }
                if let creationDate = asset.creationDate {
                    correctName = dateFormatter.string(from: creationDate)
                    // Add a number to differentiate burst photos
                    if burstIdentifier != nil && burstIdentifier == asset.burstIdentifier {
                        burstCount += 1
                        correctName += "_\(burstCount)"
                    } else {
                        burstCount = 0
                    }
                    burstIdentifier = asset.burstIdentifier
                }
                correctName += "." + fileExtension.lowercased()

                // Check if picture uploaded before
                guard !assetAlreadyUploaded(assetName: correctName, realm: realm) else {
                    Log.photoLibraryUploader("Asset ignored because it was uploaded before")
                    return
                }

                // Store a new upload file in base
                let uploadFile = UploadFile(
                    parentDirectoryId: settings.parentDirectoryId,
                    userId: settings.userId,
                    driveId: settings.driveId,
                    name: correctName,
                    asset: asset,
                    conflictOption: .version,
                    priority: initial ? .low : .high
                )
                if settings.createDatedSubFolders {
                    uploadFile.setDatedRelativePath()
                }
                realm.add(uploadFile, update: .modified)

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

    func assetAlreadyUploaded(assetName: String, realm: Realm) -> Bool {
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

    /// Wrapper type to map an "UploadFile" to a "PHAsset"
    public struct PicturesAssets {
        /// Collection of primary keys of "UploadFile"
        public let filesPrimaryKeys: [String]

        /// collection of PHAsset
        public let assets: PHFetchResult<PHAsset>
    }

    public func getPicturesToRemove() -> PicturesAssets? {
        Log.photoLibraryUploader("getPicturesToRemove")
        // Check that we have photo sync enabled with the delete option
        guard let settings = settings, settings.deleteAssetsAfterImport else {
            Log.photoLibraryUploader("no settings")
            return nil
        }

        var toRemoveFileIDs = [String]()
        var toRemoveAssets = PHFetchResult<PHAsset>()
        BackgroundRealm.uploads.execute { realm in
            toRemoveFileIDs = uploadQueue
                .getUploadedFiles(using: realm)
                .filter("rawType = %@", UploadFileType.phAsset.rawValue)
                .map { $0.id }
            toRemoveAssets = PHAsset.fetchAssets(withLocalIdentifiers: toRemoveFileIDs, options: nil)
        }

        guard toRemoveAssets.count >= Self.removeAssetsCountThreshold,
              uploadQueue.operationQueue.operationCount == 0 else {
            return nil
        }

        return PicturesAssets(filesPrimaryKeys: toRemoveFileIDs, assets: toRemoveAssets)
    }

    public func removePicturesFromPhotoLibrary(_ toRemoveItems: PicturesAssets) {
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
                    Log.photoLibraryUploader("removePicturesFromPhotoLibrary success")
                } catch {
                    Log.photoLibraryUploader("removePicturesFromPhotoLibrary error:\(error)", level: .error)
                }
            }
        }
    }
}
