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

/// Something that can save a PHAsset
public protocol PhotoLibrarySavable {
    var assetCollection: PHAssetCollection? { get }

    func save(url: URL, type: PHAssetMediaType) async throws
}

public final class PhotoLibrarySaver: PhotoLibrarySavable {
    private let albumName = "kDrive"

    public private(set) var assetCollection: PHAssetCollection?

    init() {
        // META: keep SonarCloud happy
    }

    private func requestAuthorization() async -> PHAuthorizationStatus {
        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    private func requestAuthorizationAndCreateAlbum() async throws {
        let status = await requestAuthorization()
        let authorized = status == .authorized || status == .limited
        if authorized {
            try await createAlbumIfNeeded()
        } else {
            throw DriveError.photoLibraryWriteAccessDenied
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

        if collection.firstObject != nil {
            return collection.firstObject
        }
        return nil
    }

    public func save(url: URL, type: PHAssetMediaType) async throws {
        try await requestAuthorizationAndCreateAlbum()
        try await PHPhotoLibrary.shared().performChanges {
            let assetChangeRequest: PHAssetChangeRequest?
            switch type {
            case .image:
                assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            case .video:
                assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            default:
                assetChangeRequest = nil
            }
            if let assetPlaceholder = assetChangeRequest?.placeholderForCreatedAsset,
               let assetCollection = self.assetCollection,
               let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection) {
                albumChangeRequest.addAssets([assetPlaceholder] as NSFastEnumeration)
            }
        }
    }
}
