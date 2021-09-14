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

class FileInformationCategoriesTableViewCell: UITableViewCell {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!

    var categories = [kDriveCore.Category]() {
        didSet {
            collectionView.reloadData()
        }
    }

    private var contentSizeObservation: NSKeyValueObservation?

    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.register(cellView: CategoryCollectionViewCell.self)
        collectionView.dataSource = self
        // Observe content size to adjust table view cell height (need to call `cell.layoutIfNeeded()`)
        contentSizeObservation = collectionView.observe(\.contentSize) { [weak self] collectionView, _ in
            self?.collectionViewHeightConstraint.constant = collectionView.contentSize.height
        }
    }

    deinit {
        contentSizeObservation?.invalidate()
    }
}

extension FileInformationCategoriesTableViewCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: CategoryCollectionViewCell.self, for: indexPath)

        let category = categories[indexPath.row]
        cell.configure(with: category)

        return cell
    }
}
