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

import Foundation
import kDriveCore
import kDriveResources
import UIKit

class HomePhotoListController: HomeRecentFilesController {
    private let minColumns = 3
    private let cellMaxWidth = 150.0

    required convenience init(driveFileManager: DriveFileManager, homeViewController: HomeViewController) {
        self.init(driveFileManager: driveFileManager, homeViewController: homeViewController,
                  listCellType: HomeLastPicCollectionViewCell.self, gridCellType: HomeLastPicCollectionViewCell.self,
                  emptyCellType: .noImages,
                  title: KDriveResourcesStrings.Localizable.galleryTitle,
                  selectorTitle: KDriveResourcesStrings.Localizable.galleryTitle,
                  listStyleEnabled: false)
    }

    override func getFiles() async throws -> [File] {
        return try await driveFileManager.lastPictures(page: page).files
    }

    override func getLayout(for style: ListStyle, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        // Compute number of columns based on collection view size
        let screenWidth = layoutEnvironment.container.effectiveContentSize.width
        let maxColumns = Int(screenWidth / cellMaxWidth)
        let columns = max(minColumns, maxColumns)

        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalWidth(1 / Double(columns))
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = [getHeaderLayout()]
        return section
    }

    override class func initInstance(driveFileManager: DriveFileManager, homeViewController: HomeViewController) -> Self {
        return Self(driveFileManager: driveFileManager, homeViewController: homeViewController)
    }
}
