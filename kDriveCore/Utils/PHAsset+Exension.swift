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
import Photos
import Sentry

extension PHAsset {
    public static func containsPhotosAvailableInHEIC(assetIdentifiers: [String]) -> Bool {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
        var containsHEICPhotos = false
        assets.enumerateObjects { asset, _, stop in
            if let resource = asset.bestResource(), resource.uniformTypeIdentifier == UTI.heic.identifier {
                containsHEICPhotos = true
                stop.pointee = true
            }
        }
        return containsHEICPhotos
    }

    public func getFilename(uti: UTI) -> String? {
        guard let resource = bestResource() else { return nil }

        let lastPathComponent = resource.originalFilename.split(separator: ".")
        return "\(lastPathComponent[0]).\(uti.preferredFilenameExtension ?? "")"
    }

    public func bestResource() -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: self)

        if mediaType == .video {
            if let modifiedVideoResource = resources.first(where: { $0.type == .fullSizeVideo }) {
                return modifiedVideoResource
            }
            if let originalVideoResource = resources.first(where: { $0.type == .video }) {
                return originalVideoResource
            }
            return resources.first
        }
        if mediaType == .image {
            if let modifiedImageResource = resources.first(where: { $0.type == .fullSizePhoto }) {
                return modifiedImageResource
            }
            if let originalImageResource = resources.first(where: { $0.type == .photo }) {
                return originalImageResource
            }
            return resources.first
        }
        return nil
    }

    public func getUrl(preferJPEGFormat: Bool) async -> URL? {
        guard let resource = bestResource() else { return nil }

        let requestResourceOption = PHAssetResourceRequestOptions()
        requestResourceOption.isNetworkAccessAllowed = true

        var resourceUTI = UTI(resource.uniformTypeIdentifier)
        var shouldTransformIntoJPEG = false
        if resourceUTI == .heic && preferJPEGFormat {
            resourceUTI = .jpeg
            shouldTransformIntoJPEG = true
        }

        let targetURL = FileImportHelper.instance.generateImportURL(for: resourceUTI)
        do {
            if shouldTransformIntoJPEG {
                if let jpegData = try await getJpegData(for: resource, requestResourceOption: requestResourceOption) {
                    try jpegData.write(to: targetURL)
                    return targetURL
                }
                return nil
            }
            try await PHAssetResourceManager.default().writeData(for: resource, toFile: targetURL, options: requestResourceOption)
            return targetURL
        } catch {
            let breadcrumb = Breadcrumb(level: .error, category: "PHAsset request data and write")
            breadcrumb.message = error.localizedDescription
            SentrySDK.addBreadcrumb(crumb: breadcrumb)
        }
        return nil
    }

    private func getJpegData(for resource: PHAssetResource, requestResourceOption: PHAssetResourceRequestOptions) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            var imageData = Data()
            PHAssetResourceManager.default().requestData(for: resource, options: requestResourceOption) { data in
                // Get all pieces of data
                imageData.append(data)
            } completionHandler: { error in
                if let error = error {
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
