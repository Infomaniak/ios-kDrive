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

import DifferenceKit
import Foundation
import kDriveCore
import UIKit

class HomeRecentFilesController {
    let driveFileManager: DriveFileManager
    weak var homeViewController: HomeViewController?

    var emptyCellType: EmptyTableView.EmptyTableViewType {
        return .noActivities
    }

    var listStyle: ListStyle = .list
    var page = 1
    var empty = false
    var loading = false
    var moreComing = true

    init(driveFileManager: DriveFileManager, homeViewController: HomeViewController) {
        self.driveFileManager = driveFileManager
        self.homeViewController = homeViewController
    }

    func cancelLoading() {
        homeViewController = nil
    }

    func loadNextPage(forceRefresh: Bool = false) {}

    func getEmptyLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        return NSCollectionLayoutSection(group: group)
    }

    func configureEmptyCell(_ cell: HomeEmptyFilesCollectionViewCell) {
        cell.configureCell(with: emptyCellType)
    }

    func getLayout(for style: ListStyle) -> NSCollectionLayoutSection {
        switch style {
        case .list:
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
            return NSCollectionLayoutSection(group: group)
        case .grid:
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(1 / 3))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
            return NSCollectionLayoutSection(group: group)
        }
    }

    func getCell(for style: ListStyle) -> UICollectionViewCell.Type {
        let cellType: UICollectionViewCell.Type
        switch style {
        case .list:
            cellType = FileCollectionViewCell.self
        case .grid:
            cellType = FileGridCollectionViewCell.self
        }
        return cellType
    }
}
