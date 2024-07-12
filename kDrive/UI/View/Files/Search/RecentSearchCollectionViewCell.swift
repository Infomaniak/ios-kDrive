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

import InfomaniakCoreUI
import kDriveCore
import UIKit

class RecentSearchCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var contentInsetView: UIView!
    @IBOutlet weak var highlightedView: UIView!
    @IBOutlet weak var recentSearchTitle: IKLabel!
    var removeButtonHandler: ((UIButton) -> Void)?

    override var isHighlighted: Bool {
        didSet {
            setHighlighting()
        }
    }

    func setHighlighting() {
        highlightedView?.isHidden = !isHighlighted
    }

    func initStyle(isFirst: Bool, isLast: Bool) {
        if isLast && isFirst {
            contentInsetView.roundCorners(
                corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner],
                radius: 10
            )
        } else if isFirst {
            contentInsetView.roundCorners(corners: [.layerMaxXMinYCorner, .layerMinXMinYCorner], radius: 10)
        } else if isLast {
            contentInsetView.roundCorners(corners: [.layerMaxXMaxYCorner, .layerMinXMaxYCorner], radius: 10)
        } else {
            contentInsetView.roundCorners(
                corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner],
                radius: 0
            )
        }
        contentInsetView.clipsToBounds = true
    }

    func configureWith(recentSearch: String) {
        recentSearchTitle.text = recentSearch
    }

    @IBAction func removeButtonPressed(_ sender: UIButton) {
        removeButtonHandler?(sender)
    }
}
