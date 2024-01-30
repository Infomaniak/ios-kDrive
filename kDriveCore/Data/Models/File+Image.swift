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

import Kingfisher
import UIKit

public extension File {
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
    func getPreview(completion: @escaping ((UIImage?) -> Void)) -> Kingfisher.DownloadTask? {
        if let currentDriveFileManager = accountManager.currentDriveFileManager {
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
        } else {
            return nil
        }
    }
}
