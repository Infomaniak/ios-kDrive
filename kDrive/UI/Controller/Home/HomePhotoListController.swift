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

class HomePhotoListController: HomeRecentFilesController {
    convenience init(driveFileManager: DriveFileManager, homeViewController: HomeViewController) {
        self.init(driveFileManager: driveFileManager, homeViewController: homeViewController, listCellType: HomeLastPicCollectionViewCell.self, gridCellType: HomeLastPicCollectionViewCell.self, emptyCellType: .noImages, title: KDriveStrings.Localizable.allPictures, listStyleEnabled: false)
    }

    override func loadNextPage(forceRefresh: Bool = false) {
        guard !loading && moreComing else {
            return
        }
        loading = true

        driveFileManager.getLastPictures(page: page) { response, _ in
            self.loading = false
            if let files = response {
                self.empty = self.page == 1 && files.isEmpty
                self.moreComing = files.count == DriveApiFetcher.itemPerPage
                self.page += 1

                DispatchQueue.main.async {
                    self.homeViewController?.reloadWith(fetchedFiles: files, isEmpty: self.empty)
                }
            }
        }
    }

    override func getLayout(for style: ListStyle) -> NSCollectionLayoutSection {
        var section: NSCollectionLayoutSection
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(1 / 3))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 3)
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        section = NSCollectionLayoutSection(group: group)

        section.boundarySupplementaryItems = [getHeaderLayout()]
        return section
    }
}
