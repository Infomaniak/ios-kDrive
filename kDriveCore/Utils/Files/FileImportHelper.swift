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
import InfomaniakConcurrency
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveResources
import Photos
import RealmSwift

// TODO: move to core
protocol ItemProviderResultable {
    var result: Result<(url: URL, title: String), Error> { get async }
    var URLResult: Result<URL, Error> { get async }
}

extension ItemProviderResultable {
    var URLResult: Result<URL, Error> {
        get async {
            let result = await result
            switch result {
            case .success((let url, _)):
                return .success(url)
            case .failure(let error):
                return .failure(error)
            }
        }
    }
}

extension ItemProviderURLRepresentation: ItemProviderResultable {}

extension ItemProviderFileRepresentation: ItemProviderResultable {}

extension ItemProviderZipRepresentation: ItemProviderResultable {}

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
    /// Shorthand for default FileManager
    private let fileManager = FileManager.default

    @LazyInjectService var pathProvider: AppGroupPathProvidable
    @LazyInjectService var uploadDataSource: UploadServiceDataSourceable
    @LazyInjectService var appContextService: AppContextServiceable

    static let imageCompression = 0.8

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

        /// The type needs dedicated handling
        case unsupportedUnderlyingType
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
                let results: [Result<ImportedFile, Error>?] = try await assetIdentifiers.concurrentMap { assetIdentifier in
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
                    var fileName = url.lastPathComponent
                    if let uti,
                       let originalName = asset.getFilename(uti: uti) {
                        fileName = originalName
                    }

                    var finalUrl: URL
                    if self.appContextService.isExtension {
                        // In extension, we need to copy files to a path within appGroup to be able to upload from the main app.
                        let appGroupURL = try URL.appGroupImportUniqueFolderURL()

                        // Get import URL
                        let appGroupFileURL = appGroupURL.appendingPathComponent(fileName)
                        try self.fileManager.copyItem(atPath: url.path, toPath: appGroupFileURL.path)
                        finalUrl = appGroupFileURL
                    } else {
                        // Path obtained within the main app are stable, and will stay accessible.
                        finalUrl = url
                    }

                    let importedFile = ImportedFile(name: fileName, path: finalUrl, uti: uti ?? .data)
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
                let results: [Result<URL, Error>?] = try await safeArray.values.concurrentMap { itemProvider in
                    let underlyingType = itemProvider.underlyingType
                    switch underlyingType {
                    case .isURL:
                        let getPlist = try ItemProviderURLRepresentation(from: itemProvider)
                        progress.addChild(getPlist.progress, withPendingUnitCount: perItemUnitCount)
                        return await getPlist.URLResult

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

                        return await getFile.URLResult

                    case .isDirectory:
                        let getFile = try ItemProviderZipRepresentation(from: itemProvider)
                        progress.addChild(getFile.progress, withPendingUnitCount: perItemUnitCount)
                        return await getFile.URLResult

                    case .none:
                        return .failure(ErrorDomain.UTINotFound)

                    default:
                        return .failure(ErrorDomain.unsupportedUnderlyingType)
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
                let processedFiles: [ImportedFile] = try await results.concurrentCompactMap { taskResult in
                    guard case .success(let url) = taskResult else {
                        return nil
                    }

                    let fileName = url.lastPathComponent
                    let uti = UTI(filenameExtension: url.pathExtension) ?? UTI.data

                    var finalUrl: URL
                    if self.appContextService.isExtension {
                        // In extension, we need to copy files to a path within appGroup to be able to upload from the main app.
                        let appGroupURL = try URL.appGroupImportUniqueFolderURL()

                        // Get import URL
                        let appGroupFileURL = appGroupURL.appendingPathComponent(fileName)
                        try self.fileManager.copyItem(atPath: url.path, toPath: appGroupFileURL.path)
                        finalUrl = appGroupFileURL
                    } else {
                        // Path obtained within the main app are stable, and will stay accessible.
                        finalUrl = url
                    }

                    let importedFile = ImportedFile(name: fileName, path: finalUrl, uti: uti)
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

// TODO: move to core
extension URL {
    /// Build a path where a file can be moved within the appGroup while preventing collisions
    ///
    /// Uses the importDirectoryURL, that exists within the appGroup, to allow for easy cleaning.
    static func appGroupImportUniqueFolderURL() throws -> URL {
        // Use a unique folder to prevent collisions
        @InjectService var pathProvider: AppGroupPathProvidable
        let targetFolderURL = pathProvider.importDirectoryURL
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetFolderURL, withIntermediateDirectories: true)
        return targetFolderURL
    }
}
