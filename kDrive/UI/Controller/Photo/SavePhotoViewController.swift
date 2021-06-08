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
import kDriveCore

class SavePhotoViewController: SaveFileViewController {

    var photo: UIImage!
    var videoUrl: URL!
    var uti: UTI!
    var format = PhotoFileFormat(rawValue: 0)!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: ScanTypeTableViewCell.self)
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
            cell.didSelectIndex = { index in
                self.format = PhotoFileFormat(rawValue: index)!
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
            return HomeTitleView.instantiate(title: KDriveStrings.Localizable.searchFilterTitle)
        default:
            return super.tableView(tableView, viewForHeaderInSection: section)
        }
    }

    override func didClickOnButton() {
        guard let filename = items.first?.name,
            let selectedDriveFileManager = selectedDriveFileManager,
            let selectedDirectory = selectedDirectory else {
            return
        }

        if let uploadNewFile = selectedDirectory.rights?.uploadNewFile.value, !uploadNewFile {
            UIConstants.showSnackBar(message: KDriveStrings.Localizable.allFileAddRightError)
            return
        }

        var data: Data!
        let name: String
        if uti == .image {
            switch format {
            case .jpg:
                data = photo.jpegData(compressionQuality: imageCompression)
            case .heic:
                data = photo.heicData(compressionQuality: imageCompression)
            case .png:
                if photo.imageOrientation != .up {
                    let format = photo.imageRendererFormat
                    photo = UIGraphicsImageRenderer(size: photo.size, format: format).image { _ in
                        photo.draw(at: .zero)
                    }
                }
                data = photo.pngData()
            }
            name = filename.addingExtension(format.extension)
        } else {
            data = try? Data(contentsOf: videoUrl)
            name = filename.addingExtension("mov")
        }
        let filepath = DriveFileManager.constants.importDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
        do {
            try data?.write(to: filepath)
            let newFile = UploadFile(
                parentDirectoryId: selectedDirectory.id,
                userId: AccountManager.instance.currentAccount.userId,
                driveId: selectedDriveFileManager.drive.id,
                url: filepath,
                name: name
            )
            UploadQueue.instance.addToQueue(file: newFile)
            dismiss(animated: true) {
                if let parent = self.presentingViewController {
                    parent.dismiss(animated: true) {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.allUploadInProgress(name))
                    }
                } else {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.allUploadInProgress(name))
                }
            }
        } catch {
            UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorUpload)
        }
    }

    override class func instantiate(driveFileManager: DriveFileManager?) -> SavePhotoViewController {
        let viewController = Storyboard.photo.instantiateViewController(withIdentifier: "SavePhotoViewController") as! SavePhotoViewController
        viewController.selectedDriveFileManager = driveFileManager
        return viewController
    }
}
