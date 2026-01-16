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
import Kingfisher
import UIKit

public extension File {
    /// Get a Thumbnail for a file from a public share
    @discardableResult
    func getPublicShareThumbnail(publicShareId: String,
                                 publicDriveId: Int,
                                 publicFileId: Int,
                                 token: String? = nil,
                                 completion: @escaping ((UIImage, Bool) -> Void)) -> Kingfisher.DownloadTask? {
        guard supportedBy.contains(.thumbnail) else {
            completion(icon, false)
            return nil
        }

        let thumbnailURL = Endpoint.shareLinkFileThumbnail(driveId: publicDriveId,
                                                           linkUuid: publicShareId,
                                                           fileId: publicFileId,
                                                           token: token).url

        return KingfisherManager.shared.retrieveImage(with: thumbnailURL) { result in
            if let image = try? result.get().image {
                completion(image, true)
            } else {
                // The file can become invalidated while retrieving the icon online
                completion(
                    self.isInvalidated ? ConvertedType.unknown.icon : self
                        .icon,
                    false
                )
            }
        }
    }

    /// Get a Thumbnail for a file for the current DriveFileManager
    @discardableResult
    func getThumbnail(completion: @escaping ((UIImage, Bool) -> Void)) -> Kingfisher.DownloadTask? {
        if supportedBy.contains(.thumbnail), let currentDriveFileManager = accountManager.currentDriveFileManager {
            return KingfisherManager.shared.retrieveImage(with: thumbnailURL,
                                                          options: [.requestModifier(currentDriveFileManager.apiFetcher
                                                                  .authenticatedKF)]) { result in
                if let image = try? result.get().image {
                    completion(image, true)
                } else {
                    // The file can become invalidated while retrieving the icon online
                    completion(self.isInvalidated ? ConvertedType.unknown.icon : self.icon, false)
                }
            }
        } else {
            completion(icon, false)
            return nil
        }
    }

    @discardableResult
    func getPublicSharePreview(publicShareId: String,
                               publicDriveId: Int,
                               publicFileId: Int,
                               token: String? = nil,
                               completion: @escaping ((UIImage?) -> Void)) -> Kingfisher.DownloadTask? {
        let previewURL = Endpoint.shareLinkFilePreview(driveId: publicDriveId,
                                                       linkUuid: publicShareId,
                                                       fileId: publicFileId,
                                                       token: token).url

        return KingfisherManager.shared.retrieveImage(with: previewURL) { result in
            if let image = try? result.get().image {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }

    @discardableResult
    func getPreview(completion: @escaping ((UIImage?) -> Void)) -> Kingfisher.DownloadTask? {
        guard let currentDriveFileManager = accountManager.currentDriveFileManager else {
            return nil
        }

        return KingfisherManager.shared.retrieveImage(with: imagePreviewUrl,
                                                      options: [
                                                          .requestModifier(currentDriveFileManager.apiFetcher
                                                              .authenticatedKF),
                                                          .preloadAllAnimationData
                                                      ]) { result in
            if let image = try? result.get().image {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }
}
