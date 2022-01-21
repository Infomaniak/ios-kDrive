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

import Photos
import UIKit

public class PhotoLibrarySaver: NSObject {
    private let albumName = "kDrive"
    public static let instance = PhotoLibrarySaver()

    public private(set) var assetCollection: PHAssetCollection?

    override private init() {
        super.init()
    }

    private func requestAuthorization() async -> PHAuthorizationStatus {
        if #available(iOS 14, *) {
            return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        } else {
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private func requestAuthorizationAndCreateAlbum() async throws {
        let status = await requestAuthorization()
        let authorized: Bool
        if #available(iOS 14, *) {
            authorized = status == .authorized || status == .limited
        } else {
            authorized = status == .authorized
        }
        if authorized {
            try await createAlbumIfNeeded()
        } else {
            throw DriveError.localError
        }
    }

    private func createAlbumIfNeeded() async throws {
        if let assetCollection = fetchAssetCollectionForAlbum() {
            self.assetCollection = assetCollection
        } else {
            try await PHPhotoLibrary.shared().performChanges { [albumName] in
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            }
            assetCollection = fetchAssetCollectionForAlbum()
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

    public func save(image: UIImage) async throws {
        try await requestAuthorizationAndCreateAlbum()
        try await PHPhotoLibrary.shared().performChanges {
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset

            if let assetCollection = self.assetCollection, let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection) {
                let enumeration: NSArray = [assetPlaceHolder!]
                albumChangeRequest.addAssets(enumeration)
            }
        }
    }

    public func save(videoUrl: URL) async throws {
        try await requestAuthorizationAndCreateAlbum()
        try await PHPhotoLibrary.shared().performChanges {
            if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoUrl) {
                let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset
                if let assetCollection = self.assetCollection, let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection) {
                    let enumeration: NSArray = [assetPlaceHolder!]
                    albumChangeRequest.addAssets(enumeration)
                }
            }
        }
    }
}
