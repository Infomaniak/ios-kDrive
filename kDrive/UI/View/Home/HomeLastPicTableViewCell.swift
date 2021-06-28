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

class HomeLastPicTableViewCell: UITableViewCell {

    @IBOutlet weak var collectionView: UICollectionView!

    var files = [File]()
    var isLoading = false
    weak var delegate: HomeFileDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.delegate = self
        collectionView.dataSource = self

        collectionView.register(cellView: HomeLastPicCollectionViewCell.self)
    }

    func configureLoading() {
        self.isLoading = true
        collectionView.reloadData()
    }

    func configureWith(files: [File]) {
        self.files = files
        self.isLoading = false
        collectionView.reloadData()
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        self.contentView.frame = self.bounds
        self.contentView.layoutIfNeeded()
        return CGSize(width: collectionView.contentSize.width, height: collectionView.contentSize.height + 8) // Add top margin
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource
extension HomeLastPicTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isLoading ? 10 : files.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: HomeLastPicCollectionViewCell.self, for: indexPath)
        if isLoading {
            cell.configureLoading()
        } else {
            cell.configureWith(file: files[indexPath.row])
        }
        return cell
    }

    // MARK: - Collection view delegate

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return !isLoading
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return !isLoading
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelect(index: indexPath.row, files: files)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension HomeLastPicTableViewCell: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let collectionViewLayout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return .zero
        }
        let numberOfColumns = UIDevice.current.orientation.isLandscape ? 3 : 2
        let width = collectionView.bounds.width - safeAreaInsets.left - safeAreaInsets.right - collectionViewLayout.minimumInteritemSpacing * CGFloat(numberOfColumns - 1)
        let cellWidth = width / CGFloat(numberOfColumns)
        return CGSize(width: cellWidth, height: cellWidth)
    }
}
