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

import UIKit
import Kingfisher

public class IconUtils {

    public static func getIcon(for file: File) -> UIImage {
        if file.isDirectory {
            switch file.visibility {
            case .isTeamSpace:
                return KDriveCoreAsset.folderCommonDocuments.image
            case .isSharedSpace:
                return KDriveCoreAsset.folderShared.image
            case .isCollaborativeFolder:
                return KDriveCoreAsset.folderDropBox.image
            default:
                return (file.isDisabled ? KDriveCoreAsset.folderDisable : KDriveCoreAsset.folderFilled).image
            }
        } else {
            return file.convertedType.icon
        }
    }

    public static func getThumbnail(for file: File, completion: @escaping ((UIImage, Bool) -> (Void))) {
        if file.isDirectory {
            switch file.visibility {
            case .isTeamSpace:
                completion(KDriveCoreAsset.folderCommonDocuments.image, false)
            case .isSharedSpace:
                completion(KDriveCoreAsset.folderShared.image, false)
            case .isCollaborativeFolder:
                completion(KDriveCoreAsset.folderDropBox.image, false)
            default:
                if file.isDisabled {
                    completion(KDriveCoreAsset.folderDisable.image, false)
                } else {
                    completion(KDriveCoreAsset.folderFilled.image, false)
                }
            }
        } else {
            if file.hasThumbnail, let currentDriveFileManager = AccountManager.instance.currentDriveFileManager {
                KingfisherManager.shared.retrieveImage(with: file.thumbnailURL, options: [.requestModifier(currentDriveFileManager.apiFetcher.authenticatedKF)]) { result in
                    if let image = try? result.get().image {
                        completion(image, true)
                    } else {
                        completion(file.icon, false)
                    }
                }
            } else {
                completion(file.icon, false)
            }
        }
    }

}
