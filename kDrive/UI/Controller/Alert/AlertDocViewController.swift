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

import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

/// Alert to create a new office document
class AlertDocViewController: AlertFieldViewController {
    @LazyInjectService private var router: AppNavigable

    private let fileType: String
    private let directory: File
    private let driveFileManager: DriveFileManager

    /**
     Creates a new alert to create a new office document.
     - Parameters:
        - fileType: Type of the office file to create (docx, pptx, xlsx, or txt)
        - directory: Directory where to create the document
     */
    init(fileType: String, directory: File, driveFileManager: DriveFileManager) {
        self.fileType = fileType
        self.directory = directory
        self.driveFileManager = driveFileManager
        super.init(
            title: KDriveResourcesStrings.Localizable.modalCreateFileTitle,
            label: KDriveResourcesStrings.Localizable.hintInputFileName,
            placeholder: nil,
            action: KDriveResourcesStrings.Localizable.buttonCreate,
            handler: nil
        )
        textFieldConfiguration = .fileNameConfiguration
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Image view
        let typeImage = UIImageView()
        switch fileType {
        case "docx":
            typeImage.image = KDriveResourcesAsset.fileText.image
            typeImage.tintColor = KDriveResourcesAsset.infomaniakColor.color
        case "pptx":
            typeImage.image = KDriveResourcesAsset.filePresentation.image
            typeImage.tintColor = KDriveResourcesAsset.iconColor.color
        case "xlsx":
            typeImage.image = KDriveResourcesAsset.fileSheets.image
            typeImage.tintColor = KDriveResourcesAsset.iconColor.color
        case "txt":
            typeImage.image = KDriveResourcesAsset.fileText.image
            typeImage.tintColor = KDriveResourcesAsset.secondaryTextColor.color
        case "docxf":
            typeImage.image = KDriveResourcesAsset.fileForm.image
            typeImage.tintColor = KDriveResourcesAsset.iconColor.color
        default:
            break
        }
        typeImage.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typeImage)

        // Constraints
        leadingConstraint.isActive = false
        let constraints = [
            typeImage.widthAnchor.constraint(equalToConstant: 25),
            typeImage.heightAnchor.constraint(equalToConstant: 25),
            typeImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textField.leadingAnchor.constraint(equalTo: typeImage.trailingAnchor, constant: 8),
            textField.centerYAnchor.constraint(equalTo: typeImage.centerYAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Actions

    @objc override func action() {
        guard let name = textField.text else {
            return
        }

        setLoading(true)
        Task { [proxyDirectory = directory.proxify()] in
            var file: File?
            do {
                file = try await driveFileManager.createFile(
                    in: proxyDirectory,
                    name: name.addingExtension(fileType),
                    type: fileType
                )
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarFileCreateConfirmation)
            } catch {
                UIConstants.showSnackBarIfNeeded(error: error)
            }
            self.setLoading(false)
            self.dismiss(animated: true) {
                if let file,
                   let mainTabViewController = router.getCurrentController() {
                    OnlyOfficeViewController.open(
                        driveFileManager: self.driveFileManager,
                        file: file,
                        viewController: mainTabViewController
                    )
                }
            }
        }
    }
}
