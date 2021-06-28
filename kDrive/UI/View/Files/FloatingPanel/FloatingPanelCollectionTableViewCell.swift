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

class FloatingPanelCollectionTableViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    var menu: [FloatingPanelAction]!
    var file: File!

    weak var delegate: FileActionDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.delegate = self
        collectionView.dataSource = self

        collectionView.register(cellView: FloatingPanelCollectionViewCell.self)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: FloatingPanelCollectionViewCell.self, for: indexPath)
        let action = menu[indexPath.row]
        cell.actionImage.isHidden = action.isLoading
        action.isLoading ? cell.loadingIndicator.startAnimating() : cell.loadingIndicator.stopAnimating()
        cell.actionImage.image = action.image
        cell.actionImage.tintColor = action.tintColor
        cell.actionLabel.text = action.name
        if action == .shareLink {
            if file.visibility == .isCollaborativeFolder {
                cell.actionLabel.text = KDriveStrings.Localizable.buttonCopyLink
            } else if file.shareLink != nil {
                cell.actionLabel.text = action.reverseName
            }
        }
        cell.darkLayer.isHidden = action.isEnabled
        cell.accessibilityLabel = action.name
        cell.accessibilityTraits = action.isEnabled ? .button : .notEnabled
        cell.isAccessibilityElement = true
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = 90
        let width = Int((collectionView.frame.width / 2) - 5)
        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return menu[indexPath.row].isEnabled
    }

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return menu[indexPath.row].isEnabled
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let action = menu[indexPath.row]
        delegate?.didSelectAction(action)
    }

}
