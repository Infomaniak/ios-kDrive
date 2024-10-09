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
import kDriveResources
import UIKit

protocol DropBoxLinkDelegate: AnyObject {
    func didClickOnShareLink(link: String, sender: UIView)
}

class DropBoxLinkTableViewCell: InsetTableViewCell {
    @IBOutlet var copyTextField: UITextField!
    @IBOutlet var copyButton: ImageButton!
    weak var delegate: DropBoxLinkDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        copyButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonShare
    }

    @IBAction func
        copyButtonPressed(_ sender: UIButton) {
        delegate?.didClickOnShareLink(link: copyTextField.text ?? "", sender: sender)
    }
}
