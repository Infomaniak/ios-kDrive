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
import InfomaniakDI
import Photos
import RealmSwift

public protocol PhotoLibraryScanable {
    func scheduleNewPicturesForUpload() async
    func cancelScan() async
}

extension PhotoLibraryUploader: PhotoLibraryScanable {
    public func scheduleNewPicturesForUpload() async {
        Log.photoLibraryUploader("scheduleNewPicturesForUpload")
        guard let frozenSettings,
              PHPhotoLibrary.authorizationStatus() == .authorized else {
            Log.photoLibraryUploader("0 new assets")
            return
        }

        await cancelScan()

        let worker = Task {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            let typesPredicates = getAssetPredicates(forSettings: frozenSettings)
            let datePredicate = getDatePredicate(with: frozenSettings)
            let typePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: typesPredicates)
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, typePredicate])

            Log.photoLibraryUploader("Fetching new pictures/videos with predicate: \(options.predicate!.predicateFormat)")
            let assetsFetchResult = PHAsset.fetchAssets(with: options)
            let syncDate = Date()

            do {
                try await addImageAssetsToUploadQueue(
                    assetsFetchResult: assetsFetchResult,
                    initial: frozenSettings.lastSync.timeIntervalSince1970 == 0
                )

                if Task.isCancelled {
                    Log.photoLibraryUploader("Scan Task cancelled before updating last sync date")
                    return
                }

                try uploadsDatabase.writeTransaction { writableRealm in
                    updateLastSyncDate(syncDate, writableRealm: writableRealm)
                }

                Log.photoLibraryUploader("New assets count:\(assetsFetchResult.count)")
            } catch ErrorDomain.importCancelledBySystem {
                Log.photoLibraryUploader("System is requesting to stop", level: .error)
            } catch {
                Log.photoLibraryUploader("addImageAssetsToUploadQueue error:\(error)", level: .error)
            }
        }

        workerTask = worker
        await worker.value
    }

    public func cancelScan() async {
        guard let workerTask else {
            return
        }

        workerTask.cancel()
        await workerTask.value
        self.workerTask = nil
    }

    // MARK: - Private

    private func updateLastSyncDate(_ date: Date, writableRealm: Realm) {
        if let settings = writableRealm.objects(PhotoSyncSettings.self).first,
           !settings.isInvalidated {
            settings.lastSync = date
        }
    }

    private func addImageAssetsToUploadQueue(assetsFetchResult: PHFetchResult<PHAsset>, initial: Bool) async throws {
        Log.photoLibraryUploader("addImageAssetsToUploadQueue")
        guard let frozenSettings else {
            Log.photoLibraryUploader("no settings")
            return
        }

        let expiringActivity = ExpiringActivity(id: "addImageAssetsToUploadQueue:\(UUID().uuidString)", delegate: nil)
        expiringActivity.start()
        defer {
            expiringActivity.endAll()
        }

        autoreleasepool {
            processAssetsFetchResult(
                assetsFetchResult,
                initial: initial,
                expiringActivity: expiringActivity,
                frozenSettings: frozenSettings
            )
        }

        guard !expiringActivity.shouldTerminate else {
            throw ErrorDomain.importCancelledBySystem
        }
    }

    private func processAssetsFetchResult(
        _ assetsFetchResult: PHFetchResult<PHAsset>,
        initial: Bool,
        expiringActivity: ExpiringActivity,
        frozenSettings: PhotoSyncSettings
    ) {
        var burstIdentifier: String?
        var burstCount = 0

        assetsFetchResult.enumerateObjects { [self] asset, _, stop in
            guard !expiringActivity.shouldTerminate else {
                Log.photoLibraryUploader("system is asking to terminate")
                stop.pointee = true
                return
            }

            @InjectService var photoLibrarySaver: PhotoLibrarySavable
            if let assetCollectionIdentifier = photoLibrarySaver.assetCollection?.localIdentifier {
                let options = PHFetchOptions()
                options.predicate = NSPredicate(format: "localIdentifier = %@", assetCollectionIdentifier)
                let assetCollections = PHAssetCollection.fetchAssetCollectionsContaining(
                    asset,
                    with: .album,
                    options: options
                )
                // swiftlint:disable:next empty_count
                if assetCollections.count > 0 {
                    Log.photoLibraryUploader("Asset ignored because it already originates from kDrive")
                    return
                }
            }

            // Get a unique file identifier while taking care of the burst state
            let finalName = getPhotoLibraryName(
                forAsset: asset,
                settings: frozenSettings,
                burstIdentifier: &burstIdentifier,
                burstCount: &burstCount
            )

            if Task.isCancelled {
                Log.photoLibraryUploader("Scan Task cancelled before hashing asset")
                stop.pointee = true
                return
            }

            let bestResourceSHA256: String?
            do {
                bestResourceSHA256 = try asset.bestResourceSHA256
            } catch {
                // Error thrown while hashing a resource, we skip the asset.
                Log.photoLibraryUploader("Error while hashing:\(error) asset: \(asset.localIdentifier)", level: .error)
                return
            }

            Log.photoLibraryUploader("Asset hash:\(String(describing: bestResourceSHA256))")

            guard !expiringActivity.shouldTerminate, !Task.isCancelled else {
                Log.photoLibraryUploader("Scan Task cancelled after hashing asset")
                stop.pointee = true
                return
            }

            writeUploadFileInDatabase(
                finalName: finalName,
                asset: asset,
                bestResourceSHA256: bestResourceSHA256,
                initial: initial,
                expiringActivity: expiringActivity,
                frozenSettings: frozenSettings,
                stop: stop
            )
        }
    }

    private func writeUploadFileInDatabase(
        finalName: String,
        asset: PHAsset,
        bestResourceSHA256: String?,
        initial: Bool,
        expiringActivity: ExpiringActivity,
        frozenSettings: PhotoSyncSettings,
        stop: UnsafeMutablePointer<ObjCBool>
    ) {
        try? uploadsDatabase.writeTransaction { writableRealm in
            // Check if picture uploaded before
            guard !assetAlreadyUploaded(assetName: finalName,
                                        localIdentifier: asset.localIdentifier,
                                        bestResourceSHA256: bestResourceSHA256,
                                        writableRealm: writableRealm) else {
                Log.photoLibraryUploader("Asset ignored because it was uploaded before")
                return
            }

            guard !assetAlreadyPendingUpload(bestResourceSHA256: bestResourceSHA256,
                                             writableRealm: writableRealm) else {
                Log.photoLibraryUploader("Asset already in pending upload")
                return
            }

            let algorithmImportVersion = currentDiffAlgorithmVersion

            // New UploadFile to be uploaded. Priority is `.low`, first sync is `.normal`
            let uploadFile = UploadFile(
                parentDirectoryId: frozenSettings.parentDirectoryId,
                userId: frozenSettings.userId,
                driveId: frozenSettings.driveId,
                name: finalName,
                asset: asset,
                bestResourceSHA256: bestResourceSHA256,
                algorithmImportVersion: algorithmImportVersion,
                conflictOption: .version,
                priority: initial ? .low : .normal
            )

            // Lazy creation of sub folder if required in the upload file
            if frozenSettings.createDatedSubFolders {
                uploadFile.setDatedRelativePath()
            }

            guard !expiringActivity.shouldTerminate, !Task.isCancelled else {
                Log.photoLibraryUploader("Scan Task cancelled in transaction")
                writableRealm.cancelWrite()
                stop.pointee = true
                return
            }

            // DB insertion
            writableRealm.add(uploadFile, update: .modified)
            if let creationDate = asset.creationDate {
                updateLastSyncDate(creationDate, writableRealm: writableRealm)
            }
        }
    }

    private func assetAlreadyPendingUpload(bestResourceSHA256: String?,
                                           writableRealm: Realm) -> Bool {
        guard let bestResourceSHA256 else {
            return false
        }
        guard !writableRealm.objects(UploadFile.self).filter("bestResourceSHA256 == %@", bestResourceSHA256).isEmpty else {
            return false
        }
        return true
    }

    private func getPhotoLibraryName(
        forAsset asset: PHAsset,
        settings: PhotoSyncSettings,
        burstIdentifier: inout String?,
        burstCount: inout Int
    ) -> String {
        let correctName: String
        let fileExtension: String

        // build fileExtension
        if let resource = asset.bestResource {
            if resource.uniformTypeIdentifier == UTI.heic.identifier,
               let preferredFilenameExtension = settings.photoFormat.uti.preferredFilenameExtension {
                fileExtension = preferredFilenameExtension
            } else {
                fileExtension = UTI(resource.uniformTypeIdentifier)?.preferredFilenameExtension
                    ?? (resource.originalFilename as NSString).pathExtension
            }
        } else {
            fileExtension = ""
        }

        // Compute index of burst photos
        if burstIdentifier != nil && burstIdentifier == asset.burstIdentifier {
            burstCount += 1
        } else {
            burstCount = 0
        }
        burstIdentifier = asset.burstIdentifier

        // Only generate a different file name if has adjustments
        let modificationDate = asset.modificationDate

        // Build the same name as importing manually a file
        correctName = asset.getFilename(fileExtension: fileExtension,
                                        creationDate: asset.creationDate,
                                        modificationDate: modificationDate,
                                        burstCount: burstCount,
                                        burstIdentifier: burstIdentifier)

        return correctName
    }

    /// Determines if a PHAsset was already uploaded, for a given version of it
    /// - Parameters:
    ///   - assetName: The stable name of a file
    ///   - localIdentifier: The PHAsset local identifier
    ///   - bestResourceSHA256: A hash to identify the current resource with changes if any
    ///   - writableRealm: the realm context within a write transaction
    /// - Returns: True if already uploaded for a specific version of the file
    private func assetAlreadyUploaded(assetName: String,
                                      localIdentifier: String,
                                      bestResourceSHA256: String?,
                                      writableRealm: Realm) -> Bool {
        // Roughly 10x faster than '.first(where:'
        let uploadedPictures = writableRealm
            .objects(UploadFile.self)
            .filter(Self.uploadedAssetPredicate)

        /// Identify a PHAsset with a specific `localIdentifier` _and_ a hash, `bestResourceSHA256`, if any.
        ///
        /// Only used on iOS15 and up.
        if uploadedPictures
            .filter("assetLocalIdentifier = %@ AND bestResourceSHA256 = %@",
                    localIdentifier,
                    bestResourceSHA256 ?? "NULL")
            .first != nil {
            Log
                .photoLibraryUploader(
                    "AlreadyUploaded match with identifier:\(localIdentifier) hash:\(String(describing: bestResourceSHA256)) "
                )
            return true
        }

        /// Legacy check only _name_ of the file that should be stable
        else if uploadedPictures.filter(NSPredicate(format: "name = %@", assetName))
            .first != nil {
            Log.photoLibraryUploader("AlreadyUploaded match with name:\(assetName)")
            return true
        }

        /// Nothing found
        else {
            return false
        }
    }

    /// Get the current diff algorithm version
    private var currentDiffAlgorithmVersion: Int {
        PhotoLibraryImport.hashBestResource.rawValue
    }
}
