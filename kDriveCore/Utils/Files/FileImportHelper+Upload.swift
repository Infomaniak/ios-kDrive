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
import PDFKit
import Photos
import QuickLookThumbnailing
import RealmSwift
import VisionKit

public extension FileImportHelper {
    func upload(files: [ImportedFile], in directory: File, drive: Drive) async throws {
        guard directory.capabilities.canUpload else {
            throw ImportError.accessDenied
        }

        let parentDirectoryId = directory.id
        let userId = drive.userId
        let driveId = drive.id

        _ = try await parallelTaskMapper.map(collection: files) { file in
            let uploadFile = UploadFile(
                parentDirectoryId: parentDirectoryId,
                userId: userId,
                driveId: driveId,
                url: file.path,
                name: file.name
            )
            self.uploadQueue.saveToRealmAndAddToQueue(uploadFile: uploadFile)
        }
    }

    func upload(
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

    func upload(photo: UIImage, name: String, format: PhotoFileFormat, in directory: File, drive: Drive) throws {
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

    func upload(videoUrl: URL, name: String, in directory: File, drive: Drive) throws {
        guard directory.capabilities.canUpload else {
            throw ImportError.accessDenied
        }

        let uti = UTI.quickTimeMovie
        let name = name.addingExtension(uti.preferredFilenameExtension ?? "mov")
        let data = try Data(contentsOf: videoUrl)
        try upload(data: data, name: name, uti: uti, drive: drive, directory: directory)
    }

    /// Common upload method
    internal func upload(data: Data, name: String, uti: UTI, drive: Drive, directory: File) throws {
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

public extension FileImportHelper {
    func generateImportURL(for contentType: UTI?) -> URL {
        var url = pathProvider.importDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
        if let uti = contentType {
            url.appendPathExtension(for: uti)
        }
        return url
    }

    static func getDefaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmssSS"
        return formatter.string(from: Date())
    }
}
