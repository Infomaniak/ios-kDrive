/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import InfomaniakCoreUI
import UIKit

class CustomLargeTitleCollectionViewController: UICollectionViewController {
    private var navigationBarHeight: CGFloat {
        return navigationController?.navigationBar.frame.height ?? 0
    }

    var headerViewHeight: CGFloat = 0

    private var originalTitle: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hideBackButtonText()
    }

    static func generateHeaderItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                    heightDimension: .estimated(40))
        let headerItem = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerItemSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        headerItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        return headerItem
    }

    private func updateNavigationBarAppearance() {
        if let title = navigationItem.title {
            originalTitle = title
        }
        let scrollOffset = collectionView.contentOffset.y
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }

        let titleStyle = TextStyle.header3
        let alpha = min(1, max(0, (scrollOffset + headerViewHeight) / navigationBarHeight))
        let titleColor = titleStyle.color.withAlphaComponent(alpha)

        let newStandardNavigationBarAppearance = navigationBar.standardAppearance
        let newCompactNavigationBarAppearance = navigationBar.compactAppearance

        newStandardNavigationBarAppearance.titleTextAttributes[.foregroundColor] = titleColor
        newCompactNavigationBarAppearance?.titleTextAttributes[.foregroundColor] = titleColor

        navigationBar.standardAppearance = newStandardNavigationBarAppearance
        navigationBar.compactAppearance = newCompactNavigationBarAppearance

        navigationItem.title = alpha < 0.2 ? nil : originalTitle
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateNavigationBarAppearance()
    }
}
