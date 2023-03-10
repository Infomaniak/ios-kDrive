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

import kDriveCore
import kDriveResources
import MaterialOutlinedTextField
import UIKit

class FileNameTableViewCell: UITableViewCell, UITextFieldDelegate {
    @IBOutlet weak var textField: MaterialOutlinedTextField!
    var textDidChange: ((String?) -> Void)?
    var textDidEndEditing: ((String?) -> Void)?

    private var textFieldConfiguration = TextFieldConfiguration.fileNameConfiguration

    override func awakeFromNib() {
        super.awakeFromNib()

        textField.setInfomaniakColors()
        textField.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        textField.setHint(KDriveResourcesStrings.Localizable.saveExternalFileInputFileName)
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)

        textFieldConfiguration.apply(to: textField)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textField.setClearButton()
    }

    @objc func textFieldDidChange() {
        textDidChange?(textField.text)
    }

    // MARK: - Text field delegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let fileName = textField.text else { return }
        textFieldConfiguration.selectedRange = fileName
            .startIndex ..< (fileName.lastIndex(where: { $0 == "." }) ?? fileName.endIndex)
        textFieldConfiguration.selectText(in: textField)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textDidEndEditing?(textField.text)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
    }
}
