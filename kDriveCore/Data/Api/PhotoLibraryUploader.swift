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
import Photos
import CocoaLumberjackSwift

public class PhotoLibraryUploader {

    public static let instance = PhotoLibraryUploader()
    public var settings: PhotoSyncSettings!
    public var isSyncEnabled: Bool {
        return settings != nil
    }
    private let requestImageOption = PHImageRequestOptions()
    private let requestVideoOption = PHVideoRequestOptions()
    private let dateFormatter = DateFormatter()
    private var exportSessions = Set<AVAssetExportSession>()
    private var phRequests = Set<PHImageRequestID>()

    private init() {
        requestImageOption.deliveryMode = PHImageRequestOptionsDeliveryMode.highQualityFormat
        requestImageOption.isSynchronous = false
        requestImageOption.isNetworkAccessAllowed = true

        requestVideoOption.deliveryMode = PHVideoRequestOptionsDeliveryMode.highQualityFormat
        requestVideoOption.isNetworkAccessAllowed = true
        requestVideoOption.version = .current

        dateFormatter.dateFormat = "MM-dd-yyyy HHmmss"
        settings = DriveFileManager.constants.uploadsRealm.objects(PhotoSyncSettings.self).first?.freeze()
    }

    public func enableSyncWithSettings(_ newSettings: PhotoSyncSettings) {
        let realm = DriveFileManager.constants.uploadsRealm
        try? realm.write {
            realm.delete(realm.objects(PhotoSyncSettings.self))
            realm.add(newSettings)
        }
        settings = newSettings.freeze()
    }

    public func disableSync() {
        let realm = DriveFileManager.constants.uploadsRealm
        try? realm.write {
            realm.delete(realm.objects(PhotoSyncSettings.self))
        }
        settings = nil
    }

    private func updateLastSyncDate(_ date: Date) {
        let realm = DriveFileManager.constants.uploadsRealm
        if let settings = realm.objects(PhotoSyncSettings.self).first {
            try? realm.write {
                settings.lastSync = date
            }
            self.settings = settings.freeze()
        }
    }

    func getUrlForPHAsset(_ asset: PHAsset, completion: @escaping ((URL?) -> Void)) {
        autoreleasepool {
            if asset.mediaType == .video {
                let request = PHImageManager.default().requestAVAsset(forVideo: asset, options: requestVideoOption) { (asset, audioMix, infos) in
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
                phRequests.insert(request)
            } else if asset.mediaType == .image {
                let request = PHImageManager.default().requestImageData(for: asset, options: requestImageOption) { (data, uti, orientation, infos) in
                    let filePath = DriveFileManager.constants.importDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
                    do {
                        try data?.write(to: filePath)
                        completion(filePath)
                    } catch {
                        completion(nil)
                    }
                }
                phRequests.insert(request)
            } else {
                completion(nil)
            }
        }
    }

    func getUrlForPHAssetSync(_ asset: PHAsset) -> URL? {
        var url: URL?
        let getUrlLock = DispatchGroup()
        getUrlLock.enter()
        getUrlForPHAsset(asset) { (fetchedUrl) in
            url = fetchedUrl
            getUrlLock.leave()
        }
        getUrlLock.wait()
        return url
    }

    func cancelAllRequests() {
        for session in exportSessions {
            session.cancelExport()
        }
        exportSessions.removeAll()
        for request in phRequests {
            PHImageManager.default().cancelImageRequest(request)
        }
        phRequests.removeAll()
    }

    public func addNewPicturesToUploadQueue() -> Int {
        var assetCount = 0
        if isSyncEnabled && (PHPhotoLibrary.authorizationStatus() == .authorized || PHPhotoLibrary.authorizationStatus() == .restricted) {
            if isSyncEnabled && settings.syncPicturesEnabled {
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                options.predicate = NSPredicate(
                    format: "creationDate > %@ AND !((mediaSubtype & %d) != 0)",
                    settings.lastSync as NSDate,
                    PHAssetMediaSubtype.photoScreenshot.rawValue
                )
                let assets = PHAsset.fetchAssets(with: .image, options: options)
                addImageAssetsToUploadQueue(assets: assets)
                assetCount += assets.count
                DDLogInfo("Photo sync - New pictures count \(assets.count)")
            }
            if isSyncEnabled && settings.syncScreenshotsEnabled {
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                options.predicate = NSPredicate(
                    format: "creationDate > %@ AND (mediaSubtype & %d) != 0",
                    settings.lastSync as NSDate,
                    PHAssetMediaSubtype.photoScreenshot.rawValue
                )
                let assets = PHAsset.fetchAssets(with: .image, options: options)
                addImageAssetsToUploadQueue(assets: assets)
                assetCount += assets.count
                DDLogInfo("Photo sync - New screenshots count \(assets.count)")
            }
            if isSyncEnabled && settings.syncVideosEnabled {
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                options.predicate = NSPredicate(
                    format: "creationDate > %@",
                    settings.lastSync as NSDate
                )
                let assets = PHAsset.fetchAssets(with: .video, options: options)
                addImageAssetsToUploadQueue(assets: assets)
                assetCount += assets.count
                DDLogInfo("Photo sync - New videos count \(assets.count)")
            }
            updateLastSyncDate(Date())
            UploadQueue.instance.addToQueueFromRealm()
        }
        return assetCount
    }

    private func addImageAssetsToUploadQueue(assets: PHFetchResult<PHAsset>) {
        autoreleasepool {
            let realm = DriveFileManager.constants.uploadsRealm
            realm.beginWrite()
            for i in 0..<assets.count {
                guard settings != nil else {
                    realm.cancelWrite()
                    return
                }
                let asset = assets[i]
                var correctName = "No-name-\(Date().timeIntervalSince1970)"
                var fileExtension = ""
                for resource in PHAssetResource.assetResources(for: asset) {
                    if (resource.type == .photo && asset.mediaType == .image) {
                        fileExtension = (resource.originalFilename as NSString).pathExtension
                    } else if (resource.type == .video && asset.mediaType == .video) {
                        fileExtension = (resource.originalFilename as NSString).pathExtension
                    }
                }
                if let creationDate = asset.creationDate {
                    correctName = dateFormatter.string(from: creationDate)
                }
                correctName += "." + fileExtension.lowercased()

                let uploadFile = UploadFile(
                    parentDirectoryId: settings.parentDirectoryId,
                    userId: settings.userId,
                    driveId: settings.driveId,
                    name: correctName,
                    asset: asset,
                    creationDate: asset.creationDate)
                uploadFile.priority = settings.lastSync.timeIntervalSince1970 > 0 ? .high : .low
                realm.add(uploadFile, update: .modified)
                if i < assets.count - 1 && i % 99 == 0 {
                    // Commit write every 100 assets
                    try? realm.commitWrite()
                    UploadQueue.instance.addToQueueFromRealm()
                    realm.beginWrite()
                }
            }
            try? realm.commitWrite()
        }
    }

    func removePicturesFromPhotoLibrary(uploadQueue: [UploadFile]) {
        var toRemoveAssets = [PHAsset]()
        for upload in uploadQueue {
            if upload.getPHAsset() != nil {
                toRemoveAssets.append(upload.getPHAsset()!)
            }
        }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(toRemoveAssets as NSFastEnumeration)
        } completionHandler: { (result, error) in

        }
    }

}
