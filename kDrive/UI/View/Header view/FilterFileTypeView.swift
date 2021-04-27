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

class FilterFileTypeView: UIView {

    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var fileTypeIconImageView: UIImageView!
    @IBOutlet weak var fileTypeLabel: UILabel!
    @IBOutlet weak var fileTypeRemoveButton: UIButton!
    weak var delegate: FilesHeaderViewDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        fileTypeRemoveButton.accessibilityLabel = KDriveStrings.Localizable.buttonDelete
        contentView.roundCorners(corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner], radius: 10)
    }

    @IBAction func removeFileTypeButtonPressed(_ sender: UIButton) {
        delegate?.removeFileTypeButtonPressed()
    }

}
