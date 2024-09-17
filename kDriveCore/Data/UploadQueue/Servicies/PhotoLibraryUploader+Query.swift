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
    /// Create predicate related to dates from settings
    func getDatePredicate(with settings: PhotoSyncSettings) -> NSPredicate {
        let lastSyncDate = settings.lastSync as NSDate
        let syncFromDate = settings.fromDate as NSDate
        let datePredicate: NSPredicate

        // iOS15 and up, we fetch resources with changes
        if #available(iOS 15, *) {
            // Look also for `modificationDate` when we can query the system for more specific
            // details about the nature of the change later
            //
            // Tracking changes of files with a creation date beyond syncFromDate
            datePredicate = NSPredicate(
                format: "creationDate > %@ OR (modificationDate > %@ AND creationDate > %@)",
                lastSyncDate,
                lastSyncDate,
                syncFromDate
            )
        } else {
            // Legacy query based on name only
            datePredicate = NSPredicate(format: "creationDate > %@", lastSyncDate)
        }

        return datePredicate
    }

    /// Create predicate related to file format from settings
    func getAssetPredicates(forSettings settings: PhotoSyncSettings) -> [NSPredicate] {
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
