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
import PDFKit
import Photos
import VisionKit

public class ImportedFile {
    public var name: String
    public var path: URL
    public var uti: UTI

    public init(name: String, path: URL, uti: UTI) {
        self.name = name
        self.path = path
        self.uti = uti
    }
}

public enum PhotoFileFormat: Int, CaseIterable {
    case jpg, heic, png

    public var title: String {
        switch self {
        case .jpg:
            return "JPG"
        case .heic:
            return "HEIF"
        case .png:
            return "PNG"
        }
    }

    public var uti: UTI {
        switch self {
        case .jpg:
            return .jpeg
        case .heic:
            return .heic
        case .png:
            return .png
        }
    }

    public var `extension`: String {
        return uti.preferredFilenameExtension!
    }
}

public enum ScanFileFormat: Int, CaseIterable {
    case pdf, image

    public var title: String {
        switch self {
        case .pdf:
            return "PDF"
        case .image:
            return "Image (.JPG)"
        }
    }

    public var uti: UTI {
        switch self {
        case .pdf:
            return .pdf
        case .image:
            return .jpeg
        }
    }

    public var `extension`: String {
        return uti.preferredFilenameExtension!
    }
}

public enum ImportError: Error {
    case accessDenied
    case emptyImageData
}

public class FileImportHelper {
    public static let instance = FileImportHelper()

    private let imageCompression: CGFloat = 0.8

    // MARK: - Public methods

    public func importItems(_ itemProviders: [NSItemProvider], completion: @escaping ([ImportedFile]) -> Void) -> Progress {
        let perItemUnitCount: Int64 = 10
        let progress = Progress(totalUnitCount: Int64(itemProviders.count) * perItemUnitCount)
        let dispatchGroup = DispatchGroup()
        var items = [ImportedFile]()

        for itemProvider in itemProviders {
            dispatchGroup.enter()
            if itemProvider.hasItemConformingToTypeIdentifier(UTI.url.identifier) && !itemProvider.hasItemConformingToTypeIdentifier(UTI.fileURL.identifier) {
                // We don't handle saving web url, only file url
                progress.completedUnitCount += perItemUnitCount
                dispatchGroup.leave()
            } else if let typeIdentifier = getPreferredTypeIdentifier(for: itemProvider) {
                let childProgress = getFile(from: itemProvider, typeIdentifier: typeIdentifier) { filename, url in
                    if let url = url {
                        let name = itemProvider.suggestedName ?? self.getDefaultFileName()
                        items.append(ImportedFile(name: filename ?? name, path: url, uti: UTI(typeIdentifier) ?? .data))
                    }
                    dispatchGroup.leave()
                }
                progress.addChild(childProgress, withPendingUnitCount: perItemUnitCount)
            } else {
                // For some reason registeredTypeIdentifiers is empty (shouldn't occur)
                progress.completedUnitCount += perItemUnitCount
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .global()) {
            completion(items)
        }

        return progress
    }

    public func upload(files: [ImportedFile], in directory: File, drive: Drive, userId: Int = AccountManager.instance.currentUserId) throws {
        if let uploadNewFile = directory.rights?.uploadNewFile.value, !uploadNewFile {
            throw ImportError.accessDenied
        }

        for file in files {
            let uploadFile = UploadFile(
                parentDirectoryId: directory.id,
                userId: userId,
                driveId: drive.id,
                url: file.path,
                name: file.name
            )
            UploadQueue.instance.addToQueue(file: uploadFile)
        }
    }

    public func upload(photo: UIImage, name: String, format: PhotoFileFormat, in directory: File, drive: Drive, userId: Int = AccountManager.instance.currentUserId) throws {
        if let uploadNewFile = directory.rights?.uploadNewFile.value, !uploadNewFile {
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
        guard let data = data else {
            throw ImportError.emptyImageData
        }
        try upload(data: data, name: name, drive: drive, directory: directory, userId: userId)
    }

    public func upload(videoUrl: URL, name: String, in directory: File, drive: Drive, userId: Int = AccountManager.instance.currentUserId) throws {
        if let uploadNewFile = directory.rights?.uploadNewFile.value, !uploadNewFile {
            throw ImportError.accessDenied
        }

        let name = name.addingExtension("mov")
        let data = try Data(contentsOf: videoUrl)
        try upload(data: data, name: name, drive: drive, directory: directory, userId: userId)
    }

    @available(iOS 13.0, *)
    public func upload(scan: VNDocumentCameraScan, name: String, scanType: ScanFileFormat, in directory: File, drive: Drive, userId: Int = AccountManager.instance.currentUserId) throws {
        if let uploadNewFile = directory.rights?.uploadNewFile.value, !uploadNewFile {
            throw ImportError.accessDenied
        }

        let data: Data?
        let name = name.addingExtension(scanType.extension)
        switch scanType {
        case .pdf:
            let pdfDocument = PDFDocument()
            for i in 0 ..< scan.pageCount {
                let pdfPage = PDFPage(image: scan.imageOfPage(at: i))
                pdfDocument.insert(pdfPage!, at: i)
            }
            data = pdfDocument.dataRepresentation()
        case .image:
            let image = scan.imageOfPage(at: 0)
            data = image.jpegData(compressionQuality: imageCompression)
        }
        guard let data = data else {
            throw ImportError.emptyImageData
        }
        try upload(data: data, name: name, drive: drive, directory: directory, userId: userId)
    }

    public func getDefaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmssSS"
        return formatter.string(from: Date())
    }

    // MARK: - Private methods

    private func getPreferredTypeIdentifier(for itemProvider: NSItemProvider) -> String? {
        if itemProvider.hasItemConformingToTypeIdentifier(UTI.heic.identifier) {
            return UTI.heic.identifier
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTI.jpeg.identifier) {
            return UTI.jpeg.identifier
        } else {
            return itemProvider.registeredTypeIdentifiers.first
        }
    }

    private func getFile(from itemProvider: NSItemProvider, typeIdentifier: String, completion: @escaping (String?, URL?) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 10)
        let childProgress = itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
            if let error = error {
                DDLogError("Error while loading file representation: \(error)")
                completion(nil, nil)
            }

            if let url = url {
                let targetURL = DriveFileManager.constants.importDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: false)

                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }

                    try FileManager.default.copyItem(at: url, to: targetURL)

                    completion(url.lastPathComponent, targetURL)
                } catch {
                    DDLogError("Error while loading file representation: \(error)")
                    completion(nil, nil)
                }
            }
            progress.completedUnitCount += 2
        }
        progress.addChild(childProgress, withPendingUnitCount: 8)
        return progress
    }

    private func upload(data: Data, name: String, drive: Drive, directory: File, userId: Int) throws {
        let filepath = DriveFileManager.constants.importDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
        try data.write(to: filepath)
        let newFile = UploadFile(
            parentDirectoryId: directory.id,
            userId: userId,
            driveId: drive.id,
            url: filepath,
            name: name
        )
        UploadQueue.instance.addToQueue(file: newFile)
    }
}
