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
import Photos

extension PhotoLibraryUploader {
    func mainAssetsFetchResult(_ settings: PhotoSyncSettings) -> PHFetchResult<PHAsset> {
        let options = assetsQueryOptions(settings)
        Log
            .photoLibraryUploader(
                "Fetching new pictures/videos from photo roll with predicate: \(options.predicate?.predicateFormat ?? "")"
            )
        let fetchResult = PHAsset.fetchAssets(with: options)
        return fetchResult
    }

    func userLibrariesFetchResult(_ settings: PhotoSyncSettings) -> PHFetchResult<PHCollection> {
        let fetchResult = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        Log.photoLibraryUploader("userLibrariesFetchResult: \(fetchResult.count)")
        return fetchResult
    }

    // MARK: - Private

    /// Builds fetch options matching the current user settings and limit to last sync date.
    func assetsQueryOptions(_ settings: PhotoSyncSettings) -> PHFetchOptions {
        let options = PHFetchOptions()

        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let typesPredicates = getAssetPredicates(forSettings: settings)
        let datePredicate = NSPredicate(format: "creationDate > %@", settings.lastSync as NSDate)
        let typePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: typesPredicates)
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, typePredicate])

        return options
    }

    /// Create predicate from settings
    private func getAssetPredicates(forSettings settings: PhotoSyncSettings) -> [NSPredicate] {
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

        return typesPredicates
    }
}
