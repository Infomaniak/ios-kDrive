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
import kDriveCore
import kDriveResources
import UIKit

class ManageCategoriesTableViewCell: InsetTableViewCell {
    @IBOutlet var leadingConstraint: NSLayoutConstraint!
    @IBOutlet var trailingConstraint: NSLayoutConstraint!
    @IBOutlet var viewCenterConstraint: NSLayoutConstraint!
    @IBOutlet var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var label: IKLabel!
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var collectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var collectionViewBottomConstraint: NSLayoutConstraint!

    var categories = [kDriveCore.Category]()
    var canManage = true {
        didSet {
            selectionStyle = canManage ? .default : .none
            accessoryImageView.isHidden = !canManage
        }
    }

    private var contentBackgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
    private var contentSizeObservation: NSKeyValueObservation?

    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.register(cellView: CategoryCollectionViewCell.self)
        collectionView.dataSource = self
        (collectionView.collectionViewLayout as? AlignedCollectionViewFlowLayout)?.horizontalAlignment = .leading
        // Observe content size to adjust table view cell height (need to call `cell.layoutIfNeeded()`)
        contentSizeObservation = collectionView.observe(\.contentSize) { [weak self] collectionView, _ in
            self?.collectionViewHeightConstraint.constant = collectionView.contentSize.height
        }
    }

    deinit {
        contentSizeObservation?.invalidate()
    }

    override open func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selectionStyle != .none {
            if animated {
                UIView.animate(withDuration: 0.1) {
                    self.contentInsetView.backgroundColor = selected ? KDriveResourcesAsset.backgroundCardViewSelectedColor
                        .color : self.contentBackgroundColor
                }
            } else {
                contentInsetView.backgroundColor = selected ? KDriveResourcesAsset.backgroundCardViewSelectedColor
                    .color : contentBackgroundColor
            }
        } else {
            contentInsetView.backgroundColor = contentBackgroundColor
        }
    }

    override open func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if selectionStyle != .none {
            if animated {
                UIView.animate(withDuration: 0.1) {
                    self.contentInsetView.backgroundColor = highlighted ? KDriveResourcesAsset.backgroundCardViewSelectedColor
                        .color : self.contentBackgroundColor
                }
            } else {
                contentInsetView.backgroundColor = highlighted ? KDriveResourcesAsset.backgroundCardViewSelectedColor
                    .color : contentBackgroundColor
            }
        } else {
            contentInsetView.backgroundColor = contentBackgroundColor
        }
    }

    func configure(with categories: [kDriveCore.Category]) {
        if categories.isEmpty {
            label.text = canManage ? KDriveResourcesStrings.Localizable.addCategoriesTitle : KDriveResourcesStrings.Localizable
                .categoriesFilterTitle
            collectionViewBottomConstraint.constant = 0
            viewCenterConstraint.isActive = true
            contentViewHeightConstraint.isActive = true
        } else {
            label.text = canManage ? KDriveResourcesStrings.Localizable.manageCategoriesTitle : KDriveResourcesStrings.Localizable
                .categoriesFilterTitle
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
        contentBackgroundColor = UIColor.systemBackground
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
