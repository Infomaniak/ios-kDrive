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
    /// - Throws: if the system is trying to end a background activity
    var baseImageSHA256: String? { get throws }

    /// Computes the SHA of the `.bestResource` available
    ///
    /// Anything accessible with a `requestData` will work (photo / video …)
    /// A picture with adjustments will see its hash change here
    /// - Throws: if the system is trying to end a background activity
    var bestResourceSHA256: String? { get throws }
}

/// Something that will be called in case an asset activity is expiring
///
/// It will unlock a linked TolerantDispatchGroup, and write an error to a given reference
final class AssetExpiringActivityDelegate: ExpiringActivityDelegate {
    enum ErrorDomain: Error {
        case assetActivityExpired
    }

    let group: TolerantDispatchGroup
    var error: Error?

    init(group: TolerantDispatchGroup) {
        self.group = group
    }

    func backgroundActivityExpiring() {
        error = ErrorDomain.assetActivityExpired
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
        get throws {
            guard #available(iOS 15, *) else {
                return nil
            }

            // We build an ExpiringActivity to track system termination
            let uid = "\(#function)-\(asset.localIdentifier)-\(UUID().uuidString)"
            let group = TolerantDispatchGroup()
            let activityDelegate = AssetExpiringActivityDelegate(group: group)
            let activity = ExpiringActivity(id: uid, delegate: activityDelegate)
            activity.start()

            var hash: String?

            let options = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = { _ -> Bool in
                return true
            }

            group.enter()
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
            group.wait()

            activity.endAll()

            guard let error = activityDelegate.error else {
                // All good
                return hash
            }

            // The processing of the hash was interrupted by the system
            throw error
        }
    }

    var bestResourceSHA256: String? {
        get throws {
            guard #available(iOS 15, *) else {
                return nil
            }

            guard let bestResource = asset.bestResource else {
                let hashFallback = try baseImageSHA256
                return hashFallback
            }

            let hasher = StreamHasher<SHA256>()

            // We build an ExpiringActivity to track system termination
            let uid = "\(#function)-\(asset.localIdentifier)-\(UUID().uuidString)"
            let group = TolerantDispatchGroup()
            let activityDelegate = AssetExpiringActivityDelegate(group: group)
            let activity = ExpiringActivity(id: uid, delegate: activityDelegate)
            activity.start()

            // TODO: Check iCloud behaviour
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            options.progressHandler = { progress in
                Log.photoLibraryUploader("hashing resource \(progress * 100)% …")
            }

            group.enter()
            PHAssetResourceManager.default().requestData(for: bestResource,
                                                         options: options) { data in
                hasher.update(data)
            } completionHandler: { error in
                hasher.finalize()
                group.leave()
            }
            group.wait()

            activity.endAll()

            guard let error = activityDelegate.error else {
                // All good
                return hasher.digestString
            }

            // The processing of the hash was interrupted by the system
            throw error
        }
    }
}
