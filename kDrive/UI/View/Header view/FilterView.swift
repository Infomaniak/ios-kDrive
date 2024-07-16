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

class FilterView: UIView {
    @IBOutlet var collectionView: UICollectionView!

    weak var delegate: FilesHeaderViewDelegate?

    private var filters = [Filterable]()

    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.register(cellView: SearchFilterCollectionViewCell.self)
        collectionView.dataSource = self
    }

    func configure(with filters: Filters) {
        self.filters = filters.asCollection
        collectionView.reloadData()
    }
}

// MARK: - Collection view data source

extension FilterView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filters.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: SearchFilterCollectionViewCell.self, for: indexPath)

        let filter = filters[indexPath.row]
        cell.configure(with: filter)
        cell.delegate = self

        return cell
    }
}

// MARK: - Filter cell delegate

extension FilterView: SearchFilterCellDelegate {
    func removeButtonPressed(_ filter: Filterable) {
        delegate?.removeFilterButtonPressed(filter)
    }
}
