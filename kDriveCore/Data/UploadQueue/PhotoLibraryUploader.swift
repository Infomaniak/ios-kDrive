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
import Photos
import RealmSwift
import Sentry
import InfomaniakDI

public class PhotoLibraryUploader {
    @LazyInjectService var uploadQueue: UploadQueue

    public private(set) var settings: PhotoSyncSettings?
    public var isSyncEnabled: Bool {
        return settings != nil
    }

    private let dateFormatter = DateFormatter()

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
        try? realm.write {
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

    class AsyncResult<T> {
        private var result: T?
        private let group = DispatchGroup()

        init() {
            group.enter()
        }

        func get() -> T {
            group.wait()
            return result!
        }

        func set(_ result: T) {
            self.result = result
            group.leave()
        }
    }

    func getUrlSync(for asset: PHAsset) -> URL? {
        let result = AsyncResult<URL?>()
        Task {
            await result.set(asset.getUrl(preferJPEGFormat: settings?.photoFormat == .jpg))
        }
        return result.get()
    }

    public func addNewPicturesToUploadQueue(using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Int {
        guard let settings = settings,
              PHPhotoLibrary.authorizationStatus() == .authorized else {
            return 0
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        // Create predicate from settings
        var typesPredicates = [NSPredicate]()
        if settings.syncPicturesEnabled && settings.syncScreenshotsEnabled {
            typesPredicates.append(NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue))
        } else if settings.syncPicturesEnabled {
            typesPredicates.append(NSPredicate(format: "(mediaType == %d) AND !((mediaSubtype & %d) == %d)", PHAssetMediaType.image.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue))
        } else if settings.syncScreenshotsEnabled {
            typesPredicates.append(NSPredicate(format: "(mediaType == %d) AND ((mediaSubtype & %d) == %d)", PHAssetMediaType.image.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue))
        }
        if settings.syncVideosEnabled {
            typesPredicates.append(NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue))
        }
        let datePredicate = NSPredicate(format: "creationDate > %@", settings.lastSync as NSDate)
        let typePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: typesPredicates)
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, typePredicate])
        DDLogInfo("Fetching new pictures/videos with predicate: \(options.predicate!.predicateFormat)")
        let assets = PHAsset.fetchAssets(with: options)
        let syncDate = Date()
        addImageAssetsToUploadQueue(assets: assets, initial: settings.lastSync.timeIntervalSince1970 == 0, using: realm)
        DDLogInfo("Photo sync - New assets count \(assets.count)")
        updateLastSyncDate(syncDate, using: realm)
        uploadQueue.addToQueueFromRealm()
        return assets.count
    }

    private func addImageAssetsToUploadQueue(assets: PHFetchResult<PHAsset>,
                                             initial: Bool,
                                             using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        autoreleasepool {
            var burstIdentifier: String?
            var burstCount = 0
            realm.beginWrite()
            assets.enumerateObjects { [self] asset, idx, stop in
                guard let settings = settings else {
                    realm.cancelWrite()
                    stop.pointee = true
                    return
                }
                if let assetCollectionIdentifier = PhotoLibrarySaver.instance.assetCollection?.localIdentifier {
                    let options = PHFetchOptions()
                    options.predicate = NSPredicate(format: "localIdentifier = %@", assetCollectionIdentifier)
                    let assetCollections = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: options)
                    // swiftlint:disable:next empty_count
                    if assetCollections.count > 0 {
                        DDLogInfo("Asset ignored because it already originates from kDrive")
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

                let uploadFile = UploadFile(
                    parentDirectoryId: settings.parentDirectoryId,
                    userId: settings.userId,
                    driveId: settings.driveId,
                    name: correctName,
                    asset: asset,
                    conflictOption: .replace,
                    priority: initial ? .low : .high)
                if settings.createDatedSubFolders {
                    uploadFile.setDatedRelativePath()
                }
                realm.add(uploadFile, update: .modified)

                if idx < assets.count - 1 && idx % 99 == 0 {
                    // Commit write every 100 assets if it's not the last
                    try? realm.commitWrite()
                    if let creationDate = asset.creationDate {
                        updateLastSyncDate(creationDate, using: realm)
                    }
                    uploadQueue.addToQueueFromRealm()
                    realm.beginWrite()
                }
            }
            try? realm.commitWrite()
        }
    }

    public struct PicturesAssets {
        /// This array should only be accessed from the BackgroundRealm thread
        public let files: [UploadFile]
        public let assets: PHFetchResult<PHAsset>
    }

    public func getPicturesToRemove() -> PicturesAssets? {
        // Check that we have photo sync enabled with the delete option
        guard let settings = settings, settings.deleteAssetsAfterImport else {
            return nil
        }

        let removeAssetsCountThreshold = 10

        var toRemoveFiles = [UploadFile]()
        var toRemoveAssets = PHFetchResult<PHAsset>()
        BackgroundRealm.uploads.execute { realm in
            toRemoveFiles = Array(uploadQueue.getUploadedFiles(using: realm).filter("rawType = %@", UploadFileType.phAsset.rawValue))
            toRemoveAssets = PHAsset.fetchAssets(withLocalIdentifiers: toRemoveFiles.map(\.id), options: nil)
        }

        guard toRemoveAssets.count >= removeAssetsCountThreshold && uploadQueue.operationQueue.operationCount == 0 else {
            return nil
        }

        return PicturesAssets(files: toRemoveFiles, assets: toRemoveAssets)
    }

    public func removePicturesFromPhotoLibrary(_ toRemoveItems: PicturesAssets) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(toRemoveItems.assets)
        } completionHandler: { success, _ in
            if success {
                BackgroundRealm.uploads.execute { realm in
                    try? realm.write {
                        realm.delete(toRemoveItems.files)
                    }
                }
            }
        }
    }
}
