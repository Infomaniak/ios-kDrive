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

    let title: String
    let emptyCellType: EmptyTableView.EmptyTableViewType
    let listCellType: UICollectionViewCell.Type
    let gridCellType: UICollectionViewCell.Type

    var listStyle: ListStyle = .list
    var page = 1
    var empty = false
    var loading = false
    var moreComing = true

    init(driveFileManager: DriveFileManager, homeViewController: HomeViewController, listCellType: UICollectionViewCell.Type, gridCellType: UICollectionViewCell.Type, emptyCellType: EmptyTableView.EmptyTableViewType, title: String, listStyleEnabled: Bool) {
        self.title = title
        self.listCellType = listCellType
        self.gridCellType = gridCellType
        self.emptyCellType = emptyCellType

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

        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = [getHeaderLayout()]
        return section
    }

    func configureEmptyCell(_ cell: HomeEmptyFilesCollectionViewCell) {
        cell.configureCell(with: emptyCellType)
    }

    func getHeaderLayout() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(55))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        return header
    }

    func getLayout(for style: ListStyle) -> NSCollectionLayoutSection {
        var section: NSCollectionLayoutSection
        switch style {
        case .list:
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
            section = NSCollectionLayoutSection(group: group)
        case .grid:
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(1 / 3))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24 - 8, bottom: 0, trailing: 24 - 8)
            section = NSCollectionLayoutSection(group: group)
        }
        section.boundarySupplementaryItems = [getHeaderLayout()]
        return section
    }
}
