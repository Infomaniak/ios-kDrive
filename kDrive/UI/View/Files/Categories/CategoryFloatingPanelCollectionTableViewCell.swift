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

protocol CategoryActionDelegate: AnyObject {
    func didSelectAction(_ action: CategoryFloatingPanelAction)
}

class CategoryFloatingPanelCollectionTableViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var collectionView: UICollectionView!

    weak var delegate: CategoryActionDelegate?

    var actions = [CategoryFloatingPanelAction]()

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.delegate = self
        collectionView.dataSource = self

        collectionView.register(cellView: FloatingPanelCollectionViewCell.self)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return actions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: FloatingPanelCollectionViewCell.self, for: indexPath)
        let action = actions[indexPath.row]
        cell.actionImage.isHidden = false
        cell.actionImage.image = action.image
        cell.actionImage.tintColor = action.tintColor
        cell.actionLabel.text = action.name
        cell.darkLayer.isHidden = true
        cell.accessibilityLabel = action.name
        cell.accessibilityTraits = .button
        cell.isAccessibilityElement = true
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = 90
        let width = Int((collectionView.frame.width / 2) - 5)
        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let action = actions[indexPath.row]
        delegate?.didSelectAction(action)
    }
}
