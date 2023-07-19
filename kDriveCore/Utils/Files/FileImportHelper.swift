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
import PDFKit
import Photos
import QuickLookThumbnailing
import RealmSwift
import VisionKit

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
    @LazyInjectService private var uploadQueue: UploadQueue
    @LazyInjectService private var pathProvider: AppGroupPathProvidable

    private let parallelTaskMapper = ParallelTaskMapper()

    private let imageCompression = 0.8

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

                            // TODO: handle .heic .jpg tranform here.

                            let getFile = try ItemProviderFileRepresentation(from: itemProvider)
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
                    // TODO: pass the actual UTI
                    let importedFile = ImportedFile(name: fileName, path: url, uti: UTI.archive)
                    return importedFile
                }

                // Dispatch results
                Task { @MainActor in
                    // Make sure progress is displaying completion
                    progress.completedUnitCount = progress.totalUnitCount

                    completion(processedFiles, errorCount)
                }

            } catch {
                DDLogError("[FileImportHelper] importItems:\(error)")
            }
        }

        return progress

        /*
                 for itemProvider in itemProviders {
                     // Todo remove Task later
                     dispatchGroup.enter()

                     let underlyingType = itemProvider.underlyingType
                     switch underlyingType {
                     case .isURL:
                         let getPlist = try ItemProviderWeblocRepresentation(from: itemProvider)
                         progress.addChild(getPlist.progress, withPendingUnitCount: perItemUnitCount)

                         let resultURL = try await getPlist.result.get()

                         // TODO: migrate to async design
                         handleLoadObjectResult(result, for: itemProvider,
                                                uti: .internetShortcut,
                                                extension: "webloc",
                                                importedItems: &items,
                                                errorCount: &errorCount)
                         dispatchGroup.leave()
                     case .isText:
                         let childProgress = getTextFile(from: itemProvider,
                                                         typeIdentifier: UTI.plainText.identifier) { [weak self] result in
                             self?.handleLoadObjectResult(result, for: itemProvider,
                                                          uti: .plainText,
                                                          extension: UTI.plainText.preferredFilenameExtension ?? "txt",
                                                          importedItems: &items,
                                                          errorCount: &errorCount)
                             dispatchGroup.leave()
                         }
                         progress.addChild(childProgress, withPendingUnitCount: perItemUnitCount)
                     case .isUIImage:
                         let childProgress = getImage(from: itemProvider) { [weak self] result in
                             self?.handleLoadObjectResult(result, for: itemProvider,
                                                          uti: .image,
                                                          extension: "png",
                                                          importedItems: &items,
                                                          errorCount: &errorCount)
                             dispatchGroup.leave()
                         }
                         progress.addChild(childProgress, withPendingUnitCount: perItemUnitCount)
                     case .isImageData:
                         guard let typeIdentifier = getPreferredImageTypeIdentifier(
                             for: itemProvider,
                             userPreferredPhotoFormat: userPreferredPhotoFormat
                         ) else {
                             progress.completedUnitCount += perItemUnitCount
                             errorCount += 1
                             dispatchGroup.leave()
                             continue
                         }

                         let childProgress = getFile(from: itemProvider, typeIdentifier: typeIdentifier) { result in
                             switch result {
                             case .success((let filename, let fileURL)):
                                 items.append(ImportedFile(name: filename, path: fileURL, uti: UTI(typeIdentifier) ?? .data))
                             case .failure(let error):
                                 DDLogError("[FileImportHelper] Error while getting imageData file: \(error)")
                                 errorCount += 1
                             }
                             dispatchGroup.leave()
                         }
                         progress.addChild(childProgress, withPendingUnitCount: perItemUnitCount)
                     case .isCompressedData(let typeIdentifier):
                         let childProgress = getFile(from: itemProvider, typeIdentifier: typeIdentifier) { result in
                             switch result {
                             case .success((let filename, let fileURL)):
                                 items.append(ImportedFile(name: filename, path: fileURL, uti: UTI(typeIdentifier) ?? .data))
                             case .failure(let error):
                                 DDLogError("[FileImportHelper] Error while getting compressedData file: \(error)")
                                 errorCount += 1
                             }
                             dispatchGroup.leave()
                         }
                         progress.addChild(childProgress, withPendingUnitCount: perItemUnitCount)
                     case .isDirectory:

                         // TODO: use itemProvider.zippedRepresentation

                         let tmpDirectoryURL = pathProvider.tmpDirectoryURL
                         let tempURL = tmpDirectoryURL.appendingPathComponent("\(UUID().uuidString).zip")

                         _ = itemProvider.loadObject(ofClass: URL.self) { path, error in
                             guard error == nil, let path: URL = path else {
                                 progress.completedUnitCount += perItemUnitCount
                                 errorCount += 1
                                 dispatchGroup.leave()
                                 return
                             }

                             // compress content of folder and move it somewhere we can safely store it for upload
                             var error: NSError?
                             coordinator.coordinate(readingItemAt: path, options: [.forUploading], error: &error) { zipURL in
                                 do {
                                     let zipName = zipURL.lastPathComponent
                                     try fileManager.moveItem(at: zipURL, to: tempURL)

                                     items.append(ImportedFile(name: zipName, path: tempURL, uti: UTI.zip))
                                     progress.completedUnitCount += perItemUnitCount
                                     dispatchGroup.leave()
                                 } catch {
                                     DDLogError("could not move zipped file:\(error)")
                                     progress.completedUnitCount += perItemUnitCount
                                     errorCount += 1
                                     dispatchGroup.leave()
                                     return
                                 }
                             }
                         }
                     case .isMiscellaneous(let typeIdentifier):
                         let childProgress = getFile(from: itemProvider, typeIdentifier: typeIdentifier) { result in
                             switch result {
                             case .success((let filename, let fileURL)):
                                 items.append(ImportedFile(name: filename, path: fileURL, uti: UTI(typeIdentifier) ?? .data))
                             case .failure(let error):
                                 DDLogError("[FileImportHelper] Error while getting miscellaneous file: \(error)")
                                 errorCount += 1
                             }
                             dispatchGroup.leave()
                         }
                         progress.addChild(childProgress, withPendingUnitCount: perItemUnitCount)
                     case .none:
                         // For some reason registeredTypeIdentifiers is empty (shouldn't occur)
                         progress.completedUnitCount += perItemUnitCount
                         errorCount += 1
                         dispatchGroup.leave()
                     }
                 }

                 dispatchGroup.notify(queue: .global()) {
                     completion(items, errorCount)
                 }

                return progress
                  */
    }

    public func upload(files: [ImportedFile], in directory: File, drive: Drive) throws {
        guard directory.capabilities.canUpload else {
            throw ImportError.accessDenied
        }

        for file in files {
            let uploadFile = UploadFile(
                parentDirectoryId: directory.id,
                userId: drive.userId,
                driveId: drive.id,
                url: file.path,
                name: file.name
            )
            uploadQueue.saveToRealmAndAddToQueue(uploadFile: uploadFile)
        }
    }

    public func upload(photo: UIImage, name: String, format: PhotoFileFormat, in directory: File, drive: Drive) throws {
        guard directory.capabilities.canUpload else {
            throw ImportError.accessDenied
        }

        let name = name.addingExtension(format.extension)
        let data: Data?
        switch format {
        case .jpg:
            data = photo.jpegData(compressionQuality: imageCompression)
        case .heic:
            data = photo.heicData(compressionQuality: imageCompression)
        case .png:
            var photo = photo
            if photo.imageOrientation != .up {
                let format = photo.imageRendererFormat
                photo = UIGraphicsImageRenderer(size: photo.size, format: format).image { _ in
                    photo.draw(at: .zero)
                }
            }
            data = photo.pngData()
        }
        guard let data else {
            throw ImportError.emptyImageData
        }
        try upload(data: data, name: name, uti: format.uti, drive: drive, directory: directory)
    }

    public func upload(videoUrl: URL, name: String, in directory: File, drive: Drive) throws {
        guard directory.capabilities.canUpload else {
            throw ImportError.accessDenied
        }

        let uti = UTI.quickTimeMovie
        let name = name.addingExtension(uti.preferredFilenameExtension ?? "mov")
        let data = try Data(contentsOf: videoUrl)
        try upload(data: data, name: name, uti: uti, drive: drive, directory: directory)
    }

    public func upload(
        scan: VNDocumentCameraScan,
        name: String,
        scanType: ScanFileFormat,
        in directory: File,
        drive: Drive
    ) throws {
        if !directory.capabilities.canUpload {
            throw ImportError.accessDenied
        }

        let data: Data?
        let name = name.addingExtension(scanType.extension)
        switch scanType {
        case .pdf:
            let pdfDocument = PDFDocument()
            for i in 0 ..< scan.pageCount {
                let pageImage = scan.imageOfPage(at: i)
                // Compress page image before adding it to the PDF
                if let pageData = pageImage.jpegData(compressionQuality: imageCompression),
                   let compressedPageImage = UIImage(data: pageData),
                   let pdfPage = PDFPage(image: compressedPageImage) {
                    pdfDocument.insert(pdfPage, at: i)
                }
            }
            data = pdfDocument.dataRepresentation()
        case .image:
            let image = scan.imageOfPage(at: 0)
            data = image.jpegData(compressionQuality: imageCompression)
        }
        guard let data else {
            throw ImportError.emptyImageData
        }
        try upload(data: data, name: name, uti: scanType.uti, drive: drive, directory: directory)
    }

    public static func getDefaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmssSS"
        return formatter.string(from: Date())
    }

    public func generateImportURL(for contentType: UTI?) -> URL {
        var url = DriveFileManager.constants.importDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
        if let uti = contentType {
            url.appendPathExtension(for: uti)
        }
        return url
    }

    // MARK: - Private methods

    // TODO: Remove for an async await version
//    private func handleLoadObjectResult(_ result: Result<URL, Error>,
//                                        for itemProvider: NSItemProvider,
//                                        uti: UTI,
//                                        extension: String,
//                                        importedItems: inout [ImportedFile],
//                                        errorCount: inout Int) {
//        switch result {
//        case .success(let fileURL):
//            let name = (itemProvider.suggestedName ?? FileImportHelper.getDefaultFileName()).addingExtension(`extension`)
//
//            importedItems.append(ImportedFile(name: name, path: fileURL, uti: uti))
//        case .failure(let error):
//            DDLogError("[FileImportHelper] Error while getting image: \(error)")
//            errorCount += 1
//        }
//    }

    private func getPreferredImageTypeIdentifier(for itemProvider: NSItemProvider,
                                                 userPreferredPhotoFormat: PhotoFileFormat?) -> String? {
        if itemProvider.hasItemConformingToTypeIdentifier(UTI.heic.identifier) || itemProvider
            .hasItemConformingToTypeIdentifier(UTI.jpeg.identifier) {
            if let userPreferredPhotoFormat,
               itemProvider.hasItemConformingToTypeIdentifier(userPreferredPhotoFormat.uti.identifier) {
                return userPreferredPhotoFormat.uti.identifier
            }
            return itemProvider.hasItemConformingToTypeIdentifier(UTI.heic.identifier) ? UTI.heic.identifier : UTI.jpeg.identifier
        }

        return nil
    }

    private func getURL(from itemProvider: NSItemProvider, completion: @escaping (Result<URL, Error>) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 10)
        let childProgress = itemProvider.loadObject(ofClass: URL.self) { url, error in
            if let error {
                completion(.failure(error))
            } else if let url {
                // Save the URL as a webloc file (plist)
                let content = ["URL": url.absoluteString]
                let targetURL = self.generateImportURL(for: nil).appendingPathExtension("webloc")
                do {
                    let encoder = PropertyListEncoder()
                    let data = try encoder.encode(content)
                    try data.write(to: targetURL)
                    completion(.success(targetURL))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(DriveError.unknownError))
            }
            progress.completedUnitCount += 2
        }
        progress.addChild(childProgress, withPendingUnitCount: 8)
        return progress
    }

    private func getTextFile(
        from itemProvider: NSItemProvider,
        typeIdentifier: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        itemProvider.loadItem(forTypeIdentifier: typeIdentifier) { coding, error in
            if let error {
                completion(.failure(error))
            } else if let text = coding as? String {
                let targetURL = self.generateImportURL(for: UTI(typeIdentifier))
                do {
                    try text.write(to: targetURL, atomically: true, encoding: .utf8)
                    completion(.success(targetURL))
                } catch {
                    completion(.failure(error))
                }
            } else if let data = coding as? Data {
                let targetURL = self.generateImportURL(for: UTI(typeIdentifier))
                do {
                    try data.write(to: targetURL)
                    completion(.success(targetURL))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(DriveError.unknownError))
            }
            progress.completedUnitCount = 1
        }
        return progress
    }

    private func getFile(
        from itemProvider: NSItemProvider,
        typeIdentifier: String,
        completion: @escaping (Result<(String, URL), Error>) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 10)
        let childProgress = itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
            if let error {
                completion(.failure(error))
            } else if let url {
                let targetURL = self.generateImportURL(for: UTI(typeIdentifier))
                do {
                    try FileManager.default.copyOrReplace(sourceUrl: url, destinationUrl: targetURL)
                    completion(.success((url.lastPathComponent, targetURL)))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(DriveError.unknownError))
            }
            progress.completedUnitCount += 2
        }
        progress.addChild(childProgress, withPendingUnitCount: 8)
        return progress
    }

    private func getImage(from itemProvider: NSItemProvider, completion: @escaping (Result<URL, Error>) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        itemProvider.loadItem(forTypeIdentifier: UTI.image.identifier) { coding, error in
            autoreleasepool {
                if let error {
                    completion(.failure(error))
                } else {
                    let targetURL = self.generateImportURL(for: UTI.png)

                    if let image = coding as? UIImage,
                       let data = image.pngData() {
                        do {
                            try data.write(to: targetURL)
                            completion(.success(targetURL))
                        } catch {
                            completion(.failure(error))
                        }
                    } else {
                        completion(.failure(DriveError.unknownError))
                    }
                }
                progress.completedUnitCount = 1
            }
        }
        return progress
    }

    private func upload(data: Data, name: String, uti: UTI, drive: Drive, directory: File) throws {
        let targetURL = generateImportURL(for: uti)
        try data.write(to: targetURL)
        let newFile = UploadFile(
            parentDirectoryId: directory.id,
            userId: drive.userId,
            driveId: drive.id,
            url: targetURL,
            name: name
        )
        uploadQueue.saveToRealmAndAddToQueue(uploadFile: newFile)
    }
}
