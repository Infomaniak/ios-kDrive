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

import Foundation
import InfomaniakCore
import InfomaniakDI
import Photos

public extension PHAsset {
    // MARK: - Hash

    /// Get a hash of the base image of a PHAsset _without adjustments_
    ///
    /// Will return `nil` for any other resource type (like video)
    var baseImageSHA256: String? {
        get throws {
            let identifier = PHAssetIdentifier(self)
            let hash = try identifier.baseImageSHA256
            return hash
        }
    }

    /// Hash of the best resource available. Editing a video or a picture will change this hash
    var bestResourceSHA256: String? {
        get throws {
            let identifier = PHAssetIdentifier(self)
            let hash = try identifier.bestResourceSHA256
            return hash
        }
    }

    // MARK: - Filename

    /// Get a filename that can be used by kDrive, taking into consideration the edits that may exists on a PHAsset.
    func getFilename(fileExtension: String,
                     creationDate: Date?,
                     modificationDate: Date?,
                     burstCount: Int?,
                     burstIdentifier: String?) -> String {
        let nameProvider = PHAssetNameProvider()
        return nameProvider.getFilename(fileExtension: fileExtension,
                                        originalFilename: bestResource?.originalFilename,
                                        creationDate: creationDate,
                                        modificationDate: modificationDate,
                                        burstCount: burstCount,
                                        burstIdentifier: burstIdentifier)
    }

    /// Get a filename that can be used by kDrive, taking into consideration the edits that may exists on a PHAsset.
    func getFilename(uti: UTI) -> String? {
        let preferredFilenameExtension = uti.preferredFilenameExtension ?? ""
        return getFilename(
            fileExtension: preferredFilenameExtension,
            creationDate: creationDate,
            modificationDate: nil,
            burstCount: nil,
            burstIdentifier: nil
        )
    }

    /// Returns the first Resource matching a list of types.
    /// - Parameter types: The list of types we want to look for
    /// - Returns: The first match if any.
    private func firstResourceMatchingAnyType(of types: [PHAssetResourceType]) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: self)

        for type in types {
            guard let resource = resources.first(where: { $0.type == type }) else {
                continue
            }
            return resource
        }
        return nil
    }

    // MARK: - Resource

    var bestResource: PHAssetResource? {
        let typesToFetch: [PHAssetResourceType]

        switch mediaType {
        case .video:
            typesToFetch = [.fullSizeVideo, .video]
        case .image:
            typesToFetch = [.fullSizePhoto, .photo]
        default:
            // Not supported by kDrive
            return nil
        }

        // fetch the first matching type
        guard let firstMatchingResource = firstResourceMatchingAnyType(of: typesToFetch) else {
            let resources = PHAssetResource.assetResources(for: self)
            return resources.first
        }
        return firstMatchingResource
    }

    // MARK: - Url

    func getUrl(preferJPEGFormat: Bool) async -> URL? {
        guard let resource = bestResource else { return nil }

        let requestResourceOption = PHAssetResourceRequestOptions()
        requestResourceOption.isNetworkAccessAllowed = true

        var resourceUTI = UTI(resource.uniformTypeIdentifier)
        var shouldTransformIntoJPEG = false
        if resourceUTI == .heic && preferJPEGFormat {
            resourceUTI = .jpeg
            shouldTransformIntoJPEG = true
        }

        // Asset is copied when we start the Upload, thus guarantees the stability of the file
        @InjectService var fileImportHelper: FileImportHelper
        let targetURL = fileImportHelper.generateImportURL(for: resourceUTI)
        do {
            guard shouldTransformIntoJPEG else {
                try await PHAssetResourceManager.default()
                    .writeData(for: resource, toFile: targetURL, options: requestResourceOption)
                return targetURL
            }

            guard try await writeJpegData(to: targetURL, resource: resource, options: requestResourceOption) else {
                return nil
            }

            return targetURL
        } catch {
            SentryDebug.addBreadcrumb(message: error.localizedDescription, category: SentryDebug.Category.PHAsset, level: .error)
            SentryDebug.capturePHAssetResourceManagerError(error)
        }
        return nil
    }

    // MARK: - HEIC

    static func containsPhotosAvailableInHEIC(assetIdentifiers: [String]) -> Bool {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
        var containsHEICPhotos = false
        assets.enumerateObjects { asset, _, stop in
            if let resource = asset.bestResource, resource.uniformTypeIdentifier == UTI.heic.identifier {
                containsHEICPhotos = true
                stop.pointee = true
            }
        }
        return containsHEICPhotos
    }

    // MARK: - Data

    private func writeJpegData(to url: URL, resource: PHAssetResource,
                               options: PHAssetResourceRequestOptions) async throws -> Bool {
        guard let jpegData = try await getJpegData(for: resource, options: options) else { return false }
        try jpegData.write(to: url)
        let date = Date()
        let attributes = [
            FileAttributeKey.creationDate: creationDate ?? date,
            /*
                We use the creationDate instead of the modificationDate
                because this date is not always accurate.
                (It does not seem to correspond to a real modification of the image)
                Apple Feedback: FB11923430
                */
            FileAttributeKey.modificationDate: creationDate ?? date
        ]
        try? FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        return true
    }

    private func getJpegData(for resource: PHAssetResource, options: PHAssetResourceRequestOptions) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            var imageData = Data()
            PHAssetResourceManager.default().requestData(for: resource, options: options) { data in
                // Get all pieces of data
                imageData.append(data)
            } completionHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let image = CIImage(data: imageData) {
                    autoreleasepool {
                        let context = CIContext()
                        let jpegData = context.jpegRepresentation(
                            of: image,
                            colorSpace: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
                        )
                        continuation.resume(returning: jpegData)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
