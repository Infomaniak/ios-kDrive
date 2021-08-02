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
import StoreKit
import UIKit

class StoreOffersTableViewCell: UITableViewCell {
    @IBOutlet weak var collectionView: UICollectionView!

    var driveFileManager: DriveFileManager!
    var items = [StoreViewController.Item]()

    override func awakeFromNib() {
        super.awakeFromNib()

        // Set up collection view
        collectionView.register(cellView: StoreCollectionViewCell.self)
        collectionView.allowsSelection = false
        collectionView.decelerationRate = .fast
    }
}

// MARK: - Collection view data source

extension StoreOffersTableViewCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: StoreCollectionViewCell.self, for: indexPath)
        let item = items[indexPath.row]
        cell.configure(with: item, currentPack: driveFileManager.drive.pack)
        cell.delegate = self
        return cell
    }
}

// MARK: - Scroll view delegate

extension StoreOffersTableViewCell: UIScrollViewDelegate {
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let itemWidth = collectionView.bounds.size.width - 48 + 10
        let inertialTargetX = targetContentOffset.pointee.x
        let offsetFromPreviousPage = (inertialTargetX + collectionView.contentInset.left).truncatingRemainder(dividingBy: itemWidth)

        // Snap to nearest page
        let pagedX: CGFloat
        if offsetFromPreviousPage > itemWidth / 2 {
            pagedX = inertialTargetX + (itemWidth - offsetFromPreviousPage)
        } else {
            pagedX = inertialTargetX - offsetFromPreviousPage
        }

        let point = CGPoint(x: pagedX, y: targetContentOffset.pointee.y)
        targetContentOffset.pointee = point
    }
}

// MARK: - Collection view flow delegate

extension StoreOffersTableViewCell: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.size.width - 48, height: 360)
    }
}

// MARK: - Store cell delegate

extension StoreOffersTableViewCell: StoreCellDelegate {
    func selectButtonTapped(item: StoreViewController.Item) {
        if let product = item.product {
            // Attempt to purchase the tapped product
            StoreObserver.shared.buy(product, userId: AccountManager.instance.currentUserId, driveId: driveFileManager.drive.id)
        }
    }
}
