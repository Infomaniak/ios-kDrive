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

import CryptoKit
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

/// Something that will be called in case an activity is expiring
///
/// It will unlock a linked TolerantDispatchGroup, and write an error to a given reference
final class AssetExpiringActivityDelegate: ExpiringActivityDelegate {
    enum ErrorDomain: Error {
        case assetActivityExpired
    }

    let group: TolerantDispatchGroup
    var errorPointer: NSErrorPointer

    init(group: TolerantDispatchGroup, errorPointer: inout NSErrorPointer) {
        self.group = group
        self.errorPointer = errorPointer
    }

    func backgroundActivityExpiring() {
        let error = ErrorDomain.assetActivityExpired as NSError
        errorPointer?.pointee = error
        group.leave()
    }
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

        // We build an ExpiringActivity to track system termination
        let uid = "\(asset.localIdentifier)-\(UUID().uuidString)"
        let group = TolerantDispatchGroup()
        var error: NSError?
        var errorPointer = NSErrorPointer(&error)
        let activityDelegate = AssetExpiringActivityDelegate(group: group, errorPointer: &errorPointer)
        let activity = ExpiringActivity(id: uid, delegate: activityDelegate)
        activity.start()

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

        activity.endAll()

        // We need to check the errorPointer to see if it is pointing to some error
        guard errorPointer?.pointee == nil else {
            // The processing of the hash was interrupted by the system
            return nil
        }

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
        let hasher = StreamHasher<SHA256>()

        // TODO: Check iCloud behaviour
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress in
            Log.photoLibraryUploader("hashing resource \(progress * 100)% …")
        }

        PHAssetResourceManager.default().requestData(for: bestResource,
                                                     options: options) { data in
            hasher.update(data)
        } completionHandler: { error in
            hasher.finalize()
            group.leave()
        }

        // wait for the request to finish
        group.enter()
        group.wait()

        return hasher.digestString
    }
}
