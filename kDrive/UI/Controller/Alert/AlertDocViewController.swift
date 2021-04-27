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

/// Alert to create a new office document
class AlertDocViewController: AlertFieldViewController {
    private let fileType: String
    private let directory: File

    /**
     Creates a new alert to create a new office document.
     - Parameters:
        - fileType: Type of the office file to create (docx, pptx, xlsx, or txt)
        - directory: Directory where to create the document
     */
    init(fileType: String, directory: File) {
        self.fileType = fileType
        self.directory = directory
        super.init(title: KDriveStrings.Localizable.modalCreateFileTitle, label: KDriveStrings.Localizable.hintInputFileName, placeholder: nil, action: KDriveStrings.Localizable.buttonCreate, handler: nil)
        self.textFieldConfiguration = .fileNameConfiguration
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Image view
        let typeImage = UIImageView()
        switch fileType {
        case "docx":
            typeImage.image = KDriveAsset.fileText.image
            typeImage.tintColor = KDriveAsset.infomaniakColor.color
        case "pptx":
            typeImage.image = KDriveAsset.filePresentation.image
            typeImage.tintColor = KDriveAsset.iconColor.color
        case "xlsx":
            typeImage.image = KDriveAsset.fileSheets.image
            typeImage.tintColor = KDriveAsset.iconColor.color
        case "txt":
            typeImage.image = KDriveAsset.fileText.image
            typeImage.tintColor = KDriveAsset.secondaryTextColor.color
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
            textField.centerYAnchor.constraint(equalTo: typeImage.centerYAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Actions

    @objc override func action() {
        guard var name = textField.text else {
            return
        }

        name = name.hasSuffix(".\(fileType)") ? name : "\(name).\(fileType)"
        setLoading(true)
        AccountManager.instance.currentDriveFileManager.createOfficeFile(parentDirectory: directory, name: name, type: fileType) { (file, error) in
            self.setLoading(false)

            self.dismiss(animated: true) {
                let message: String
                if error == nil {
                    message = KDriveStrings.Localizable.snackbarFileCreateConfirmation
                } else {
                    message = KDriveStrings.Localizable.errorFileCreate
                }
                UIConstants.showSnackBar(message: message)
            }
        }
    }

}
