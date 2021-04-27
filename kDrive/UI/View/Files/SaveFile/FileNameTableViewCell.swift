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
import MaterialOutlinedTextField

class FileNameTableViewCell: UITableViewCell, UITextFieldDelegate {

    @IBOutlet weak var textField: MaterialOutlinedTextField!
    var textDidChange: ((String?) -> Void)?
    var textDidEndEditing: ((String?) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()

        textField.setInfomaniakColors()
        textField.backgroundColor = KDriveAsset.backgroundCardViewColor.color
        textField.setHint(KDriveStrings.Localizable.saveExternalFileInputFileName)
        textField.delegate = self
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }

    @objc func textFieldDidChange() {
        textDidChange?(textField.text)
    }

    // MARK: - Text field delegate

    func textFieldDidEndEditing(_ textField: UITextField) {
        textDidEndEditing?(textField.text)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
    }

}
