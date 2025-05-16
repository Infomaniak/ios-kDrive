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
import InfomaniakCore
import InfomaniakCoreDB
import InfomaniakDI
import Photos
import RealmSwift
import Sentry

public protocol PhotoLibraryUploadable {
    var liveSettings: PhotoSyncSettings? { get }
    var frozenSettings: PhotoSyncSettings? { get }
    var isSyncEnabled: Bool { get }
    var isWifiOnly: Bool { get }
}

public final class PhotoLibraryUploader: PhotoLibraryUploadable {
    @LazyInjectService(customTypeIdentifier: kDriveDBID.uploads) var uploadsDatabase: Transactionable
    @LazyInjectService var uploadService: UploadServiceable

    let serialQueue: DispatchQueue = {
        @LazyInjectService var appContextService: AppContextServiceable
        let autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = appContextService.isExtension ? .workItem : .inherit

        return DispatchQueue(
            label: "com.infomaniak.drive.photo-library",
            autoreleaseFrequency: autoreleaseFrequency
        )
    }()

    /// Threshold value to trigger cleaning of photo roll if enabled
    static let removeAssetsCountThreshold = 10

    /// Predicate to quickly narrow down on uploaded assets
    static let uploadedAssetPredicate = NSPredicate(format: "rawType = %@ AND uploadDate != nil", "phAsset")

    enum ErrorDomain: Error {
        /// System is asking to terminate the operation
        case importCancelledBySystem
    }

    public var liveSettings: PhotoSyncSettings? {
        return uploadsDatabase.fetchObject(ofType: PhotoSyncSettings.self) { lazyCollection in
            lazyCollection.first
        }
    }

    public var frozenSettings: PhotoSyncSettings? {
        let settings = liveSettings
        return settings?.freeze()
    }

    public var isSyncEnabled: Bool {
        return frozenSettings != nil
    }

    public var isWifiOnly: Bool {
        guard let frozenSettings else {
            return false
        }
        return frozenSettings.isWifiOnly
    }

    public init() {
        // META: SonarClound happy
    }

    func getUrl(for asset: PHAsset) async -> URL? {
        return await asset.getUrl(preferJPEGFormat: frozenSettings?.photoFormat == .jpg)
    }
}
