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

public class PhotoLibraryUploader {
    public static let instance = PhotoLibraryUploader()
    public private(set) var settings: PhotoSyncSettings?
    public var isSyncEnabled: Bool {
        return settings != nil
    }

    private let requestImageOption = PHImageRequestOptions()
    private let requestVideoOption = PHVideoRequestOptions()
    private let dateFormatter = DateFormatter()
    private var exportSessions = Set<AVAssetExportSession>()

    private init() {
        requestImageOption.deliveryMode = .highQualityFormat
        requestImageOption.isSynchronous = false
        requestImageOption.isNetworkAccessAllowed = true
        requestImageOption.progressHandler = progressHandler

        requestVideoOption.deliveryMode = .highQualityFormat
        requestVideoOption.isNetworkAccessAllowed = true
        requestVideoOption.version = .current
        requestVideoOption.progressHandler = progressHandler

        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"

        if let settings = DriveFileManager.constants.uploadsRealm.objects(PhotoSyncSettings.self).first {
            self.settings = PhotoSyncSettings(value: settings)
        }
    }

    private let progressHandler: PHAssetImageProgressHandler = { _, error, _, _ in
        if let error = error {
            let breadcrumb = Breadcrumb(level: .error, category: "PHAsset request")
            breadcrumb.message = error.localizedDescription
            SentrySDK.addBreadcrumb(crumb: breadcrumb)
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
                settings.lastSync = date
            }
            self.settings = PhotoSyncSettings(value: settings)
        }
    }

    func getUrlForPHAsset(_ asset: PHAsset, completion: @escaping ((URL?) -> Void)) {
        if asset.mediaType == .video {
            _ = PHImageManager.default().requestAVAsset(forVideo: asset, options: requestVideoOption) { asset, _, _ in
                if let assetUrl = (asset as? AVURLAsset)?.url {
                    let importPath = DriveFileManager.constants.importDirectoryURL.appendingPathComponent(assetUrl.lastPathComponent)
                    do {
                        try FileManager.default.copyOrReplace(sourceUrl: assetUrl, destinationUrl: importPath)
                        completion(importPath)
                    } catch {
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            }
        } else if asset.mediaType == .image {
            if #available(iOS 13, *) {
                _ = PHImageManager.default().requestImageDataAndOrientation(for: asset, options: requestImageOption) { data, _, _, _ in
                    self.handlePHAssetRequestData(data: data, completion: completion)
                }
            } else {
                _ = PHImageManager.default().requestImageData(for: asset, options: requestImageOption) { data, _, _, _ in
                    self.handlePHAssetRequestData(data: data, completion: completion)
                }
            }
        } else {
            completion(nil)
        }
    }

    private func handlePHAssetRequestData(data: Data?, completion: @escaping ((URL?) -> Void)) {
        if let data = data {
            let filePath = DriveFileManager.constants.importDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
            do {
                try data.write(to: filePath)
                completion(filePath)
            } catch {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }

    func getUrlForPHAssetSync(_ asset: PHAsset) -> URL? {
        var url: URL?
        let getUrlLock = DispatchGroup()
        getUrlLock.enter()
        getUrlForPHAsset(asset) { fetchedUrl in
            url = fetchedUrl
            getUrlLock.leave()
        }
        getUrlLock.wait()
        return url
    }

    public func addNewPicturesToUploadQueue(using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Int {
        var assets = PHFetchResult<PHAsset>()
        if let settings = settings, PHPhotoLibrary.authorizationStatus() == .authorized || PHPhotoLibrary.authorizationStatus() == .restricted {
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
            assets = PHAsset.fetchAssets(with: options)
            let syncDate = Date()
            addImageAssetsToUploadQueue(assets: assets, initial: settings.lastSync.timeIntervalSince1970 == 0, using: realm)
            DDLogInfo("Photo sync - New assets count \(assets.count)")
            updateLastSyncDate(syncDate, using: realm)
            UploadQueue.instance.addToQueueFromRealm()
        }
        return assets.count
    }

    private func addImageAssetsToUploadQueue(assets: PHFetchResult<PHAsset>, initial: Bool, using realm: Realm = DriveFileManager.constants.uploadsRealm) {
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
                var correctName = "No-name-\(Date().timeIntervalSince1970)"
                var fileExtension = ""
                for resource in PHAssetResource.assetResources(for: asset) {
                    if resource.type == .photo && asset.mediaType == .image {
                        fileExtension = (resource.originalFilename as NSString).pathExtension
                    } else if resource.type == .video && asset.mediaType == .video {
                        fileExtension = (resource.originalFilename as NSString).pathExtension
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
                    creationDate: asset.creationDate,
                    modificationDate: asset.modificationDate,
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
                    UploadQueue.instance.addToQueueFromRealm()
                    realm.beginWrite()
                }
            }
            try? realm.commitWrite()
        }
    }

    public struct PicturesAssets {
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
        BackgroundRealm.uploads.execute { realm in
            toRemoveFiles = Array(UploadQueue.instance.getUploadedFiles(using: realm).filter("rawType = %@", UploadFileType.phAsset.rawValue))
        }

        let toRemoveAssets = PHAsset.fetchAssets(withLocalIdentifiers: toRemoveFiles.map(\.id), options: nil)

        guard toRemoveAssets.count >= removeAssetsCountThreshold && UploadQueue.instance.operationQueue.operationCount == 0 else {
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
