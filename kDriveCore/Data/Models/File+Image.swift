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

import InfomaniakCore
import Nuke
import UIKit

public extension File {
    /// Get a Thumbnail for a file from a public share
    @discardableResult
    func getPublicShareThumbnail(publicShareId: String,
                                 publicDriveId: Int,
                                 publicFileId: Int,
                                 token: String? = nil,
                                 completion: @escaping ((UIImage, Bool) -> Void)) -> ImageTask? {
        guard supportedBy.contains(.thumbnail) else {
            completion(icon, false)
            return nil
        }

        let thumbnailURL = Endpoint.shareLinkFileThumbnail(driveId: publicDriveId,
                                                           linkUuid: publicShareId,
                                                           fileId: publicFileId,
                                                           token: token).url

        let request = ImageRequest(url: thumbnailURL)
        return ImagePipeline.shared.loadImage(with: request) { result in
            if let image = try? result.get().image {
                completion(image, true)
            } else {
                // The file can become invalidated while retrieving the icon online
                completion(self.isInvalidated ? ConvertedType.unknown.icon : self.icon, false)
            }
        }
    }

    /// Get a Thumbnail for a file for the current DriveFileManager
    @discardableResult
    func getThumbnail(completion: @escaping ((UIImage, Bool) -> Void)) -> ImageTask? {
        guard supportedBy.contains(.thumbnail),
              let authenticatedRequest = ImageRequest.authenticatedImageRequest(
                  url: thumbnailURL,
                  driveFileManager: accountManager.currentDriveFileManager
              ) else {
            completion(icon, false)
            return nil
        }

        return ImagePipeline.shared.loadImage(with: authenticatedRequest) { result in
            if let image = try? result.get().image {
                completion(image, true)
            } else {
                // The file can become invalidated while retrieving the icon online
                completion(self.isInvalidated ? ConvertedType.unknown.icon : self.icon, false)
            }
        }
    }

    @discardableResult
    func getPublicSharePreview(publicShareId: String,
                               publicDriveId: Int,
                               publicFileId: Int,
                               token: String? = nil,
                               completion: @escaping ((UIImage?) -> Void)) -> ImageTask? {
        let previewURL = Endpoint.shareLinkFilePreview(driveId: publicDriveId,
                                                       linkUuid: publicShareId,
                                                       fileId: publicFileId,
                                                       token: token).url

        let request = ImageRequest(url: previewURL)
        return ImagePipeline.shared.loadImage(with: request) { result in
            if let image = try? result.get().image {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }

    @discardableResult
    func getPreview(completion: @escaping ((UIImage?) -> Void)) -> ImageTask? {
        guard let authenticatedRequest = ImageRequest.authenticatedImageRequest(
            url: imagePreviewUrl,
            driveFileManager: accountManager.currentDriveFileManager
        ) else {
            return nil
        }

        return ImagePipeline.shared.loadImage(with: authenticatedRequest) { result in
            if let image = try? result.get().image {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }
}
