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

import InfomaniakCore
import kDriveCore
import UIKit

class ManageCategoriesTableViewCell: InsetTableViewCell {
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var trailingConstraint: NSLayoutConstraint!
    @IBOutlet var viewCenterConstraint: NSLayoutConstraint!
    @IBOutlet var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var label: IKLabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewBottomConstraint: NSLayoutConstraint!

    var categories = [kDriveCore.Category]()

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

    func configure(with categories: [kDriveCore.Category]) {
        if categories.isEmpty {
            label.text = "Ajouter des catégories"
            collectionViewBottomConstraint.constant = 0
            viewCenterConstraint.isActive = true
            contentViewHeightConstraint.isActive = true
        } else {
            label.text = "Gérer les catégories"
            collectionViewBottomConstraint.constant = 16
            viewCenterConstraint.isActive = false
            contentViewHeightConstraint.isActive = false
        }
        self.categories = categories
        collectionView.reloadData()
        layoutIfNeeded()
    }

    func initWithoutInsets() {
        initWithPositionAndShadow()
        leadingConstraint.constant = 0
        trailingConstraint.constant = 0
    }
}

extension ManageCategoriesTableViewCell: UICollectionViewDataSource {
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
