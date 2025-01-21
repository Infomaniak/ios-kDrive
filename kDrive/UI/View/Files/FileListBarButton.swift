/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import kDriveResources
import UIKit

final class FileListBarButton: UIBarButtonItem {
    private(set) var type: FileListBarButtonType = .cancel

    convenience init(type: FileListBarButtonType, target: Any?, action: Selector?) {
        switch type {
        case .selectAll:
            self.init(title: KDriveResourcesStrings.Localizable.buttonSelectAll, style: .plain, target: target, action: action)
        case .deselectAll:
            self.init(title: KDriveResourcesStrings.Localizable.buttonDeselectAll, style: .plain, target: target, action: action)
        case .loading:
            let activityView = UIActivityIndicatorView(style: .medium)
            activityView.startAnimating()
            self.init(customView: activityView)
        case .cancel:
            self.init(barButtonSystemItem: .stop, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
        case .search:
            self.init(barButtonSystemItem: .search, target: target, action: action)
        case .emptyTrash:
            self.init(title: KDriveResourcesStrings.Localizable.buttonEmptyTrash, style: .plain, target: target, action: action)
        case .searchFilters:
            self.init(image: KDriveResourcesAsset.filter.image, style: .plain, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.filtersTitle
        case .photoSort:
            self.init(image: KDriveResourcesAsset.filter.image, style: .plain, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.sortTitle
        case .addFolder:
            self.init(image: KDriveResourcesAsset.folderAdd.image, style: .plain, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.createFolderTitle
        case .downloadAll:
            let image = KDriveResourcesAsset.download.image
            self.init(image: image, style: .plain, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.buttonDownload
        case .downloadingAll:
            self.init(title: nil, style: .plain, target: target, action: action)

            let activityView = UIActivityIndicatorView(style: .medium)
            activityView.startAnimating()

            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(cancelDownloadPressed))
            activityView.addGestureRecognizer(tapGestureRecognizer)

            customView = activityView
        case .addToMyDrive:
            let image = KDriveResourcesAsset.drive.image
            self.init(image: image, style: .plain, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.buttonAddToKDrive
        }
        self.type = type
    }

    @objc private func cancelDownloadPressed() {
        guard let targetObject = target as? NSObject, let action else { return }
        targetObject.perform(action, with: self)
    }
}
