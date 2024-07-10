/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import InfomaniakCoreUI
import kDriveCore
import kDriveResources
import MaterialOutlinedTextField
import UIKit

final class TextInputTableViewCell: UITableViewCell {
    @IBOutlet var textField: MaterialOutlinedTextField!

    override func awakeFromNib() {
        super.awakeFromNib()

        textField.setInfomaniakColors()
        // TODO: i18n
        textField.setHint("Extension")
        textField.placeholder = ".jpg, .mov …"
        TextFieldConfiguration.fileExtensionConfiguration.apply(to: textField)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        guard selected != isSelected else {
            return
        }

        super.setSelected(selected, animated: animated)

        if selected {
            textField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        setSelected(false, animated: false)
        textField.text = ""
    }
}
