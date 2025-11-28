/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import UIKit

struct PhotoListLayout: FileListLayout {
    private let minColumns = 3
    private let cellMaxWidth = 150.0

    private func getColumnCountFor(width: CGFloat) -> Int {
        let maxColumns = Int(width / cellMaxWidth)
        return max(minColumns, maxColumns)
    }

    func createLayoutFor(viewModel: FileListViewModel) -> UICollectionViewLayout {
        guard let photoViewModel = viewModel as? PhotoListViewModel else {
            return DefaultFileListLayout().createLayoutFor(viewModel: viewModel)
        }

        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment -> NSCollectionLayoutSection? in
            let containerWidth = environment.container.effectiveContentSize.width
            let columns = getColumnCountFor(width: containerWidth)

            let itemFractionalWidth = 1.0 / CGFloat(columns)

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(itemFractionalWidth),
                heightDimension: .fractionalWidth(itemFractionalWidth)
            )

            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupHeight = NSCollectionLayoutDimension.fractionalWidth(itemFractionalWidth)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: groupHeight)

            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
            group.interItemSpacing = .fixed(4)

            let section = NSCollectionLayoutSection(group: group)

            let headerFooterSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                          heightDimension: .estimated(50))

            let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerFooterSize,
                                                                            elementKind: UICollectionView
                                                                                .elementKindSectionHeader,
                                                                            alignment: .top)

            section.boundarySupplementaryItems = [sectionHeader]

            if sectionIndex == photoViewModel.sections.count - 1 {
                let sectionFooter = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerFooterSize,
                                                                                elementKind: UICollectionView
                                                                                    .elementKindSectionFooter,
                                                                                alignment: .bottom)
                section.boundarySupplementaryItems.append(sectionFooter)
            }

            return section
        }

        return layout
    }
}
