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
import Photos

/// Provides identity for PHAssets, given iOS is 15 and up, NOOP otherwise.
protocol PHAssetIdentifiable {
    /// Init method
    ///
    /// Returns nil if OS is older than iOS15
    /// - Parameter asset: a required PHAsset
    init?(_ asset: PHAsset)

    /// Get a hash of the base image of a PHAsset _without adjustments_
    ///
    /// Other types of PHAsset will return nil
    var baseImageSHA256: String? { get }

    /// Computes the SHA of the `.bestResource` available
    ///
    /// Anything accessible with a `requestData` will work (photo / video …)
    /// A picture with adjustments will see its hash change here
    var bestResourceSHA256: String? { get }
}

struct PHAssetIdentifier: PHAssetIdentifiable {
    let asset: PHAsset

    init?(_ asset: PHAsset) {
        guard #available(iOS 15, *) else {
            return nil
        }

        self.asset = asset
    }

    var baseImageSHA256: String? {
        guard #available(iOS 15, *) else {
            return nil
        }

        let group = TolerantDispatchGroup()
        var hash: String?

        let options = PHContentEditingInputRequestOptions()
        options.canHandleAdjustmentData = { _ -> Bool in
            return true
        }

        // Trigger a request in order to intercept change data
        asset.requestContentEditingInput(with: options) { input, _ in
            defer {
                group.leave()
            }

            guard let input else {
                return
            }

            guard let url = input.fullSizeImageURL else {
                return
            }

            // Hashing the raw data of the picture is the only reliable solution to know when effects were applied
            // This will exclude changes related to like and albums
            hash = url.dataRepresentation.SHA256DigestString
        }

        // wait for the request to finish
        group.enter()
        group.wait()

        return hash
    }

    var bestResourceSHA256: String? {
        guard #available(iOS 15, *) else {
            return nil
        }

        guard let bestResource = asset.bestResource else {
            return baseImageSHA256
        }

        let group = TolerantDispatchGroup()
        var hash: String?
        var imageData = Data()

        // TODO: Check iCloud behaviour
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress in
            print("hashing resource \(progress * 100)% …")
        }

        PHAssetResourceManager.default().requestData(for: bestResource,
                                                     options: options) { data in
            // TODO: Hash scanning data, cannot access all at once
            imageData.append(data)
        } completionHandler: { error in
            hash = imageData.SHA256DigestString
            group.leave()
        }

        // wait for the request to finish
        group.enter()
        group.wait()

        return hash
    }
}
