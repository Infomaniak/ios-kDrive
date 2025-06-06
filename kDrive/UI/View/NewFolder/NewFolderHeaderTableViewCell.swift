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

import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import MaterialOutlinedTextField
import UIKit

protocol NewFolderTextFieldDelegate: AnyObject {
    func textFieldUpdated(content: String)
}

class NewFolderHeaderTableViewCell: InsetTableViewCell, UITextFieldDelegate {
    @IBOutlet var titleTextField: MaterialOutlinedTextField!
    weak var delegate: NewFolderTextFieldDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        titleTextField.setInfomaniakColors()
        titleTextField.autocorrectionType = .yes
        titleTextField.autocapitalizationType = .sentences
        titleTextField.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        titleTextField.delegate = self
        titleTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }

    @objc func textFieldDidChange() {
        delegate?.textFieldUpdated(content: titleTextField.text ?? "")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        // META: keep SonarCloud happy
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        // META: keep SonarCloud happy
    }

    func configureWith(folderType: FolderType) {
        if folderType == .folder {
            titleLabel.text = KDriveResourcesStrings.Localizable.createFolderTitle
            accessoryImageView.image = KDriveResourcesAsset.folderFilled.image
            titleTextField.setHint(KDriveResourcesStrings.Localizable.hintInputDirName)
        } else if folderType == .commonFolder {
            titleLabel.text = KDriveResourcesStrings.Localizable.createCommonFolderTitle
            accessoryImageView.image = KDriveResourcesAsset.folderCommonDocuments.image
            titleTextField.setHint(KDriveResourcesStrings.Localizable.hintInputDirName)
        } else {
            titleLabel.text = KDriveResourcesStrings.Localizable.createDropBoxTitle
            accessoryImageView.image = KDriveResourcesAsset.folderDropBox.image
            titleTextField.setHint(KDriveResourcesStrings.Localizable.createDropBoxHint)
        }
    }
}
