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

import kDriveResources
import UIKit

class SelectView: UIView {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var moveButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var moreButton: UIButton!

    weak var delegate: FilesHeaderViewDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 22), weight: .bold)
        titleLabel.accessibilityTraits = .header
        moveButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonMove
        deleteButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonDelete
        moreButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonMenu
    }

    func updateTitle(_ count: Int) {
        titleLabel.text = KDriveResourcesStrings.Localizable.fileListMultiSelectedTitle(count)
    }

    @IBAction func moveButtonPressed(_ sender: UIButton) {
        delegate?.moveButtonPressed()
    }

    @IBAction func deleteButtonPressed(_ sender: UIButton) {
        delegate?.deleteButtonPressed()
    }

    @IBAction func menuButtonPressed(_ sender: UIButton) {
        delegate?.menuButtonPressed()
    }
}
