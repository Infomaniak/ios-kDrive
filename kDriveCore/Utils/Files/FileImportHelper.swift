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
import InfomaniakCoreUI
import InfomaniakDI
import kDriveResources
import Photos
import RealmSwift

public enum ImportError: LocalizedError {
    case accessDenied
    case emptyImageData

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return KDriveResourcesStrings.Localizable.allFileAddRightError
        case .emptyImageData:
            return KDriveResourcesStrings.Localizable.errorUpload
        }
    }
}

public final class FileImportHelper {
    @LazyInjectService internal var pathProvider: AppGroupPathProvidable
    @LazyInjectService internal var uploadQueue: UploadQueue

    internal let imageCompression = 0.8

    let parallelTaskMapper = ParallelTaskMapper()
    
    /// Domain specific errors
    public enum ErrorDomain: Error {
        /// Not able to find the UTI of a file
        case UTINotFound

        /// Not able to find an itemProvider to process
        case itemProviderNotFound

        /// an async error was raised
        case asyncIssue(wrapping: Error)
    }

    // MARK: - Public methods

    public init() {
        /// Public Service initializer
    }

    @MainActor
    public func importAssets(
        _ assetIdentifiers: [String],
        userPreferredPhotoFormat: PhotoFileFormat? = nil,
        completion: @escaping ([ImportedFile], Int) -> Void
    ) -> Progress {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
        let progress = Progress(totalUnitCount: Int64(assets.count))

        let dispatchGroup = DispatchGroup()
        var items = [ImportedFile]()
        var errorCount = 0

        assets.enumerateObjects { asset, _, _ in
            dispatchGroup.enter()
            Task {
                if let url = await asset.getUrl(preferJPEGFormat: userPreferredPhotoFormat == .jpg) {
                    let uti = UTI(filenameExtension: url.pathExtension)
                    var name = url.lastPathComponent
                    if let uti, let originalName = asset.getFilename(uti: uti) {
                        name = originalName
                    }

                    items.append(ImportedFile(name: name, path: url, uti: uti ?? .data))
                } else {
                    errorCount += 1
                }

                progress.completedUnitCount += 1
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(items, errorCount)
        }

        return progress
    }

    public func importItems(_ itemProviders: [NSItemProvider],
                            userPreferredPhotoFormat: PhotoFileFormat? = nil,
                            completion: @escaping ([ImportedFile], Int) -> Void) -> Progress {
        let perItemUnitCount: Int64 = 10
        let progress = Progress(totalUnitCount: Int64(itemProviders.count) * perItemUnitCount)

        // using a SendableArray to pass content to a Sendable closure
        let safeArray = SendableArray<NSItemProvider>()
        safeArray.append(contentsOf: itemProviders)

        Task {
            do {
                let results: [Result<URL, Error>?] = try await self.parallelTaskMapper
                    .map(collection: safeArray.values) { itemProvider in
                        let underlyingType = itemProvider.underlyingType
                        switch underlyingType {
                        case .isURL:
                            let getPlist = try ItemProviderWeblocRepresentation(from: itemProvider)
                            progress.addChild(getPlist.progress, withPendingUnitCount: perItemUnitCount)
                            return await getPlist.result

                        case .isText:
                            let getText = try ItemProviderTextRepresentation(from: itemProvider)
                            progress.addChild(getText.progress, withPendingUnitCount: perItemUnitCount)
                            return await getText.result

                        case .isUIImage:
                            let getUIImage = try ItemProviderUIImageRepresentation(from: itemProvider)
                            progress.addChild(getUIImage.progress, withPendingUnitCount: perItemUnitCount)
                            return await getUIImage.result

                        case .isImageData, .isCompressedData, .isMiscellaneous:

                            // handle .heic .jpg tranform here.
                            let getFile = try ItemProviderFileRepresentation(
                                from: itemProvider,
                                preferredImageFileFormat: userPreferredPhotoFormat?.uti
                            )
                            progress.addChild(getFile.progress, withPendingUnitCount: perItemUnitCount)

                            return await getFile.result

                        case .isDirectory:
                            let getFile = try ItemProviderZipRepresentation(from: itemProvider)
                            progress.addChild(getFile.progress, withPendingUnitCount: perItemUnitCount)
                            return await getFile.result

                        case .none:
                            return .failure(ErrorDomain.UTINotFound)
                        }
                    }

                // Count errors
                let errorCount = results.reduce(0) { partialResult, taskResult in
                    guard case .failure = taskResult else {
                        return partialResult
                    }
                    return partialResult + 1
                }

                // Build a collection of `ImportedFile`
                let processedFiles: [ImportedFile] = results.compactMap { taskResult in
                    guard case .success(let url) = taskResult else {
                        return nil
                    }

                    let fileName = url.lastPathComponent
                    let uti = UTI(filenameExtension: url.pathExtension) ?? UTI.data
                    let importedFile = ImportedFile(name: fileName, path: url, uti: uti)
                    return importedFile
                }

                // Dispatch results
                Task { @MainActor in
                    completion(processedFiles, errorCount)
                }

            } catch {
                DDLogError("[FileImportHelper] importItems error:\(error)")
            }
        }

        return progress
    }
}
