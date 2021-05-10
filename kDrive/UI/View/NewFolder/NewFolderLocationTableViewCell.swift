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
import InfomaniakCore
import kDriveCore

class NewFolderLocationTableViewCell: InsetTableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    var path: [String] = []
    var drive: Drive!

    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.delegate = self
        collectionView.dataSource = self
        (collectionView.collectionViewLayout as! AlignedCollectionViewFlowLayout).horizontalAlignment = .leading

        collectionView.register(cellView: NewFolderLocationCollectionViewCell.self)
    }

    override func prepareForReuse() {
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return path.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: NewFolderLocationCollectionViewCell.self, for: indexPath)
        cell.titleLabel.text = path[indexPath.row]
        if indexPath.item == 0 {
            cell.accessoryImage.image = KDriveAsset.drive.image
            cell.accessoryImage.tintColor = UIColor(hex: drive.preferences.color)
        } else {
            cell.accessoryImage.image = KDriveAsset.folderCommonDocuments.image
        }
        if indexPath.item == path.count - 1 {
            cell.chevronImage.isHidden = true
        }
        return cell
    }


    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let sizeLabel = UILabel()
        sizeLabel.font = sizeLabel.font.withSize(14)
        sizeLabel.numberOfLines = 1
        sizeLabel.text = path[indexPath.row]
        sizeLabel.sizeToFit()
        return CGSize(width: min(40 + sizeLabel.bounds.width, collectionView.bounds.width), height: 26)
    }

}
