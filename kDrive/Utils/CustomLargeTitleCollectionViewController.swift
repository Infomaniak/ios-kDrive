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

import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import UIKit

class CustomLargeTitleCollectionViewController: UICollectionViewController {
    @InjectService var appRouter: AppNavigable

    private var navigationBarHeight: CGFloat {
        return navigationController?.navigationBar.frame.height ?? 0
    }

    var headerViewHeight: CGFloat = 0

    private var originalTitle: String?

    private var lastAppliedTitleAlpha: CGFloat?

    var isCompactView: Bool {
        guard let rootViewController = appRouter.rootViewController else { return false }
        return rootViewController.traitCollection.horizontalSizeClass.iskDriveCompactSize
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hideBackButtonText()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Appearance updates are suppressed while a push/pop transition is in flight (see
        // updateNavigationBarAppearance) and the navigation bar appearance is shared across the navigation
        // stack. Force a refresh once the transition has settled so we never leave a stale/outdated bar on
        // screen. transitionCoordinator is nil here, so applying the appearance is safe.
        lastAppliedTitleAlpha = nil
        updateNavigationBarAppearance()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        guard !isCompactView else {
            return
        }

        coordinator.animate(alongsideTransition: { _ in
            self.updateNavigationBarAppearance()
        }, completion: { _ in
            self.updateNavigationBarAppearance()
        })
    }

    static func generateHeaderItem(leading: CGFloat = 0) -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                    heightDimension: .estimated(40))
        let headerItem = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerItemSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        headerItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: leading, bottom: 0, trailing: 24)
        return headerItem
    }

    private func updateNavigationBarAppearance() {
        // Reassigning the navigation bar appearance while a push/pop transition is animating makes iOS 26's
        // Liquid Glass navigation bar rebuild its transition context, which re-initializes the parallax
        // dimming view and crashes with "View was already initialized". Never mutate the bar mid-transition
        // (this also covers the interactive back-swipe, which drives scrollViewDidScroll while transitioning).
        guard navigationController?.transitionCoordinator == nil else { return }

        if let title = navigationItem.title {
            originalTitle = title
        }
        let scrollOffset = collectionView.contentOffset.y
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }

        let titleStyle = TextStyle.header3
        let alpha = min(1, max(0, (scrollOffset + headerViewHeight) / navigationBarHeight))

        // Avoid redundant appearance reassignments (e.g. while the alpha stays clamped at 0 or 1 during a
        // scroll), which needlessly churn the navigation bar transition machinery for no visual change.
        if lastAppliedTitleAlpha != alpha {
            lastAppliedTitleAlpha = alpha
            let titleColor = titleStyle.color.withAlphaComponent(alpha)

            let newStandardNavigationBarAppearance = navigationBar.standardAppearance
            let newCompactNavigationBarAppearance = navigationBar.compactAppearance

            newStandardNavigationBarAppearance.titleTextAttributes[.foregroundColor] = titleColor
            newCompactNavigationBarAppearance?.titleTextAttributes[.foregroundColor] = titleColor

            navigationBar.standardAppearance = newStandardNavigationBarAppearance
            navigationBar.compactAppearance = newCompactNavigationBarAppearance
        }

        guard let originalTitle else { return }
        navigationItem.title = alpha < 0.2 ? nil : originalTitle
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateNavigationBarAppearance()
    }
}
