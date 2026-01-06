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
import UIKit

class PreviewCollectionViewCell: UICollectionViewCell {
    var tapGestureRecognizer: UITapGestureRecognizer!
    weak var previewDelegate: PreviewContentCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOnCell))
        addGestureRecognizer(tapGestureRecognizer)
    }

    @objc func didTapOnCell() {
        previewDelegate?.setFullscreen(nil)
    }

    func configureWith(file: File) {
        // META: keep SonarCloud happy
    }

    func didEndDisplaying() {
        // META: keep SonarCloud happy
    }

    func setTopInset(_ inset: CGFloat) {
        // Implemented by subclasses
    }
}
