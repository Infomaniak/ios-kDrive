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

import UIKit
import Photos

public class PhotoLibrarySaver: NSObject {
    private let albumName = "kDrive"
    public static let instance = PhotoLibrarySaver()

    private var assetCollection: PHAssetCollection?

    private override init() {
        super.init()

        if let assetCollection = fetchAssetCollectionForAlbum() {
            self.assetCollection = assetCollection
        }
    }

    private func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { (status) in
                completion(status)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { (status) in
                completion(status)
            }
        }
    }

    private func requestAuthorizationAndCreateAlbum(completion: @escaping ((_ success: Bool) -> Void)) {
        requestAuthorization { (status) in
            let authorized: Bool
            if #available(iOS 14, *) {
                authorized = status == .authorized || status == .limited
            } else {
                authorized = status == .authorized
            }
            if authorized {
                self.createAlbumIfNeeded { (success) in
                    completion(true)
                }
            } else {
                completion(false)
            }
        }
    }

    private func createAlbumIfNeeded(completion: @escaping ((_ success: Bool) -> Void)) {
        if let assetCollection = fetchAssetCollectionForAlbum() {
            self.assetCollection = assetCollection
            completion(true)
        } else {
            PHPhotoLibrary.shared().performChanges { [self] in
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            } completionHandler: { success, error in
                if success {
                    self.assetCollection = self.fetchAssetCollectionForAlbum()
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }

    private func fetchAssetCollectionForAlbum() -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let _: AnyObject = collection.firstObject {
            return collection.firstObject
        }
        return nil
    }

    public func save(image: UIImage, completion: @escaping (Bool, Error?) -> (Void)) {
        self.requestAuthorizationAndCreateAlbum { (success) in
            guard success else { return }
            PHPhotoLibrary.shared().performChanges({
                let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset

                if let assetCollection = self.assetCollection, let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection) {
                    let enumeration: NSArray = [assetPlaceHolder!]
                    albumChangeRequest.addAssets(enumeration)
                }
            }, completionHandler: completion)
        }
    }

    public func save(videoUrl: URL, completion: @escaping (Bool, Error?) -> (Void)) {
        self.requestAuthorizationAndCreateAlbum { (success) in
            guard success else { return }
            PHPhotoLibrary.shared().performChanges({
                if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoUrl) {
                    let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset
                    if let assetCollection = self.assetCollection, let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection) {
                        let enumeration: NSArray = [assetPlaceHolder!]
                        albumChangeRequest.addAssets(enumeration)
                    }
                }
            }, completionHandler: completion)
        }
    }

}
