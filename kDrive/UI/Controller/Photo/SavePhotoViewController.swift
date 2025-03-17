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

import InfomaniakCore
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class SavePhotoViewController: SaveFileViewController {
    var photo: UIImage!
    var videoUrl: URL!
    var uti: UTI!
    var format = PhotoFileFormat(rawValue: 0)!

    override func viewDidLoad() {
        tableView.register(cellView: ScanTypeTableViewCell.self)
        super.viewDidLoad()
        if uti == .image {
            sections = [.fileName, .fileType, .directorySelection]
        } else {
            sections = [.fileName, .directorySelection]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .fileType:
            let cell = tableView.dequeueReusableCell(type: ScanTypeTableViewCell.self, for: indexPath)
            cell.didSelectIndex = { [weak self] index in
                self?.format = PhotoFileFormat(rawValue: index)!
            }
            cell.configureForPhoto()
            return cell
        default:
            return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .fileType:
            return HomeTitleView.instantiate(title: KDriveResourcesStrings.Localizable.searchFilterTitle)
        default:
            return super.tableView(tableView, viewForHeaderInSection: section)
        }
    }

    override func didClickOnButton(_ sender: IKLargeButton) {
        guard let filename = items.first?.name,
              let selectedDriveFileManager,
              let selectedDirectory else {
            return
        }

        var success = false
        if uti == .image {
            do {
                try fileImportHelper.upload(
                    photo: photo,
                    name: filename,
                    format: format,
                    in: selectedDirectory,
                    drive: selectedDriveFileManager.drive
                )
                success = true
            } catch {
                success = false
            }
        } else {
            do {
                try fileImportHelper.upload(
                    videoUrl: videoUrl,
                    name: filename,
                    in: selectedDirectory,
                    drive: selectedDriveFileManager.drive
                )
                success = true
            } catch {
                success = false
            }
        }
        dismiss(animated: true) {
            if let parent = self.presentingViewController {
                parent.dismiss(animated: true) {
                    UIConstants
                        .showSnackBar(message: success ? KDriveResourcesStrings.Localizable
                            .allUploadInProgress(filename) : KDriveResourcesStrings.Localizable.errorUpload)
                }
            } else {
                UIConstants
                    .showSnackBar(message: success ? KDriveResourcesStrings.Localizable
                        .allUploadInProgress(filename) : KDriveResourcesStrings.Localizable.errorUpload)
            }
        }
    }

    override class func instantiate(driveFileManager: DriveFileManager?) -> SavePhotoViewController {
        let viewController = Storyboard.photo
            .instantiateViewController(withIdentifier: "SavePhotoViewController") as! SavePhotoViewController
        viewController.selectedDriveFileManager = driveFileManager
        return viewController
    }
}
