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

import kDriveCore
import kDriveResources
import UIKit

// MARK: - UITableViewDelegate

extension SaveFileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .fileName:
            let item = items[indexPath.row]
            if items.count > 1 {
                let alert = AlertFieldViewController(
                    title: KDriveResourcesStrings.Localizable.buttonRename,
                    placeholder: KDriveResourcesStrings.Localizable.hintInputFileName,
                    text: item.name,
                    action: KDriveResourcesStrings.Localizable.buttonSave,
                    loading: false
                ) { newName in
                    item.name = newName
                    tableView.reloadRows(at: [indexPath], with: .automatic)
                }
                alert.textFieldConfiguration = .fileNameConfiguration
                alert.textFieldConfiguration.selectedRange = item.name
                    .startIndex ..< (item.name.lastIndex { $0 == "." } ?? item.name.endIndex)
                present(alert, animated: true)
            }
        case .driveSelection:
            let selectDriveViewController = SelectDriveViewController.instantiate()
            selectDriveViewController.selectedDrive = selectedDriveFileManager?.drive
            selectDriveViewController.delegate = self
            navigationController?.pushViewController(selectDriveViewController, animated: true)
        case .directorySelection:
            guard let driveFileManager = selectedDriveFileManager else { return }
            let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(
                driveFileManager: driveFileManager,
                startDirectory: selectedDirectory,
                delegate: self
            )
            present(selectFolderNavigationController, animated: true)
        case .photoFormatOption:
            let selectPhotoFormatViewController = SelectPhotoFormatViewController
                .instantiate(selectedFormat: userPreferredPhotoFormat)
            selectPhotoFormatViewController.delegate = self
            navigationController?.pushViewController(selectPhotoFormatViewController, animated: true)
        default:
            break
        }
    }
}
