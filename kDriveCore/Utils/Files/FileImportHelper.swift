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
    private let parallelTaskMapper = ParallelTaskMapper()

    @LazyInjectService internal var pathProvider: AppGroupPathProvidable
    @LazyInjectService internal var uploadQueue: UploadQueue

    internal let imageCompression = 0.8

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
                            let getFile = try ItemProviderFile2(
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

// TODO: Move to core
public final class ItemProviderFile2: NSObject, ProgressResultable {
    /// Something to transform events to a nice `async Result`
    private let flowToAsync = FlowToAsyncResult<Success>()

    /// Shorthand for default FileManager
    private let fileManager = FileManager.default

    /// Domain specific errors
    public enum ErrorDomain: Error, Equatable {
        case UTINotFound
        case UnableToLoadFile
    }

    public typealias Success = URL
    public typealias Failure = Error

    /// Init method
    /// - Parameters:
    ///   - itemProvider: The item provider we will be working with
    ///   - preferredImageFileFormat: Specify an output image file format. Supports HEIC and JPG. Will convert only if
    /// itemProvider supports it.
    public init(from itemProvider: NSItemProvider, preferredImageFileFormat: UTI? = nil) throws {
        guard let typeIdentifier = itemProvider.registeredTypeIdentifiers.first else {
            throw ErrorDomain.UTINotFound
        }

        // Keep compiler happy
        progress = Progress(totalUnitCount: 1)

        super.init()

        // Check if requested an image conversion, and if conversion is available.
        let fileIdentifierToUse = self.preferredImageFileFormat(
            itemProvider: itemProvider,
            typeIdentifier: typeIdentifier,
            preferredImageFileFormat: preferredImageFileFormat
        )

        // Set progress and hook completion closure to a combine pipe
        progress = itemProvider.loadFileRepresentation(forTypeIdentifier: fileIdentifierToUse) { [self] fileProviderURL, error in
            guard let fileProviderURL, error == nil else {
                flowToAsync.sendFailure(error ?? ErrorDomain.UnableToLoadFile)
                return
            }

            do {
                let uti = UTI(rawValue: fileIdentifierToUse as CFString)
                @InjectService var pathProvider: AppGroupPathProvidable
                let temporaryURL = pathProvider.tmpDirectoryURL
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try fileManager.createDirectory(at: temporaryURL, withIntermediateDirectories: true)

                let fileName = fileProviderURL.appendingPathExtension2(for: uti).lastPathComponent
                let temporaryFileURL = temporaryURL.appendingPathComponent(fileName)
                try fileManager.copyItem(atPath: fileProviderURL.path, toPath: temporaryFileURL.path)

                flowToAsync.sendSuccess(temporaryFileURL)
            } catch {
                flowToAsync.sendFailure(error)
            }
        }
    }

    // MARK: ProgressResultable

    public var progress: Progress

    public var result: Result<URL, Error> {
        get async {
            await flowToAsync.result
        }
    }

    // MARK: Private

    /// Check if a File conversion is possible for the provided `itemProvider` and `typeIdentifier`,
    /// returns `typeIdentifier` if no conversion is possible.
    ///
    /// - Parameters:
    ///   - itemProvider: The ItemProvider we work with
    ///   - typeIdentifier: top typeIdentifier for ItemProvider
    ///   - preferredImageFileFormat: The image format the user is requesting
    private func preferredImageFileFormat(itemProvider: NSItemProvider,
                                          typeIdentifier: String,
                                          preferredImageFileFormat: UTI?) -> String {
        if let preferredImageFileFormat = preferredImageFileFormat {
            // Check that itemProvider supports the image types we ask of it
            if itemProvider.hasItemConformingToAnyOfTypeIdentifiers([UTI.heic.identifier, UTI.jpeg.identifier]),
               itemProvider.hasItemConformingToTypeIdentifier(preferredImageFileFormat.rawValue as String) {
                return preferredImageFileFormat.rawValue as String
            }
            // No conversion if not possible
            else {
                return typeIdentifier
            }
        } else {
            // No conversion
            return typeIdentifier
        }
    }
}

// TODO: Move to core
public extension NSItemProvider {
    /// Check if item is conforming to *at least* one identifier provided
    /// - Parameter collection: A collection of identifiers
    /// - Returns: `true` if matches for at least one identifier
    func hasItemConformingToAnyOfTypeIdentifiers(_ collection: [String]) -> Bool {
        let hasItem = collection.contains(where: { identifier in
            self.hasItemConformingToTypeIdentifier(identifier)
        })

        return hasItem
    }
}

// TODO: Move to core
extension URL {

    /// Try to append the correct file type extension for a given UTI
    func appendingPathExtension2(for contentType: UTI) -> URL {
        guard let newExtension = contentType.preferredFilenameExtension,
              pathExtension.caseInsensitiveCompare(newExtension) != .orderedSame else {
            return self
        }

        return deletingPathExtension().appendingPathExtension(newExtension)
    }
}

