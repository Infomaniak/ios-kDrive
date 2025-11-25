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
import kDriveCore
import kDriveResources
import UIKit

@MainActor
struct FileListLayout {
    private let gridMinColumns = 2
    private let gridCellMaxWidth = 200.0
    private let gridCellRatio = 3.0 / 4.0
    private let gridInnerSpacing = 8.0

    func createLayoutFor(viewModel: FileListViewModel) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, layoutEnvironment in
            if viewModel.listStyle == .list {
                return createListLayout(environment: layoutEnvironment, viewModel: viewModel)
            } else {
                return createGridLayout(environment: layoutEnvironment)
            }
        }

        return layout
    }

    private func getColumnCountFor(width: CGFloat) -> Int {
        let maxColumns = Int(width / gridCellMaxWidth)
        return max(gridMinColumns, maxColumns)
    }

    private func createGridLayout(environment: any NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let effectiveContentWidth = environment.container.effectiveContentSize.width - UIConstants.Padding.mediumSmall * 2
        let gridColumns = getColumnCountFor(width: effectiveContentWidth)

        let cellWidth = floor((effectiveContentWidth - gridInnerSpacing * 2 * CGFloat(gridColumns - 1)) / CGFloat(gridColumns))
        let size = CGSize(width: cellWidth, height: floor(cellWidth * gridCellRatio))

        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(size.width), heightDimension: .absolute(size.height))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(
            top: gridInnerSpacing,
            leading: gridInnerSpacing,
            bottom: gridInnerSpacing,
            trailing: gridInnerSpacing
        )

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(size.height))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: gridColumns)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(
            top: 0,
            leading: UIConstants.Padding.mediumSmall,
            bottom: 0,
            trailing: UIConstants.Padding.mediumSmall
        )

        return section
    }

    private func createListLayout(environment: any NSCollectionLayoutEnvironment,
                                  viewModel: FileListViewModel) -> NSCollectionLayoutSection {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        configuration.showsSeparators = false

        configuration.trailingSwipeActionsConfigurationProvider = { indexPath in
            return viewModel.getSwipeActionConfiguration(at: indexPath)
        }

        let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)

        section.contentInsets = .init(
            top: 0,
            leading: UIConstants.Padding.mediumSmall,
            bottom: 0,
            trailing: UIConstants.Padding.mediumSmall
        )

        return section
    }
}
