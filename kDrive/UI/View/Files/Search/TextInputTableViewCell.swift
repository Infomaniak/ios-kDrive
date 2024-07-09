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
import UIKit

final class TextInputTableViewCell: InsetTableViewCell {
    @IBOutlet var textField: UITextField!

    override func awakeFromNib() {
        super.awakeFromNib()

        contentInsetView.layer.cornerRadius = UIConstants.buttonCornerRadius
        contentInsetView.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        guard selected != isSelected else {
            return
        }

        super.setSelected(selected, animated: animated)

        if selected {
            contentInsetView.borderWidth = 2
            contentInsetView.borderColor = KDriveResourcesAsset.infomaniakColor.color

            textField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            contentInsetView.borderWidth = 0
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        setSelected(false, animated: false)
        textField.text = ""
    }
}
