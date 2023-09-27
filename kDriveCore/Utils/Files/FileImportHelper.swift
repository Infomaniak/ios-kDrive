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
    @LazyInjectService var pathProvider: AppGroupPathProvidable
    @LazyInjectService var uploadQueue: UploadQueue

    let imageCompression = 0.8

    let parallelTaskMapper = ParallelTaskMapper()

    /// Domain specific errors
    public enum ErrorDomain: Error {
        /// Not able to find the UTI of a file
        case UTINotFound

        /// Not able to get an URL for a resource
        case URLNotFound

        /// Not able to find an itemProvider to process
        case itemProviderNotFound

        /// an async error was raised
        case asyncIssue(wrapping: Error)
    }

    // MARK: - Public methods

    public init() {
        /// Public Service initializer
    }

    public func importAssets(
        _ assetIdentifiers: [String],
        userPreferredPhotoFormat: PhotoFileFormat? = nil,
        completion: @escaping ([ImportedFile], Int) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: Int64(assetIdentifiers.count))

        Task {
            do {
                let results: [Result<ImportedFile, Error>?] = try await self.parallelTaskMapper
                    .map(collection: assetIdentifiers) { assetIdentifier in
                        defer {
                            progress.completedUnitCount += 1
                        }

                        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject
                        else {
                            return .failure(ErrorDomain.itemProviderNotFound)
                        }

                        guard let url = await asset.getUrl(preferJPEGFormat: userPreferredPhotoFormat == .jpg) else {
                            return .failure(ErrorDomain.URLNotFound)
                        }

                        let uti = UTI(filenameExtension: url.pathExtension)
                        var name = url.lastPathComponent
                        if let uti, let originalName = asset.getFilename(uti: uti) {
                            name = originalName
                        }

                        let importedFile = ImportedFile(name: name, path: url, uti: uti ?? .data)
                        return .success(importedFile)
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
                    guard case .success(let file) = taskResult else {
                        return nil
                    }

                    return file
                }

                // Dispatch results
                Task { @MainActor in
                    completion(processedFiles, errorCount)
                }
            }
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
                            let getPlist = try ItemProviderURLRepresentation(from: itemProvider)
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
