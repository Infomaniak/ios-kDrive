/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

extension MainTabViewController {
    func addLegacyTabBarIfNeeded() {
        guard legacyTabBarActive else { return }

        tabBar.isHidden = true

        legacyTabBar.items = tabBar.items
        legacyTabBar.selectedItem = tabBar.selectedItem
        legacyTabBar.tabDelegate = self

        view.addSubview(legacyTabBar)

        legacyTabBar.translatesAutoresizingMaskIntoConstraints = false
        let bottom = legacyTabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        let leading = legacyTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let trailing = legacyTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let height = NSLayoutConstraint(item: legacyTabBar, attribute: .height, relatedBy: .equal,
                                        toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 1)
        tabBarHeightConstraint = height
        view.addConstraints([bottom, leading, trailing, height])
    }

    func willLayoutLegacyTabBarIfNeeded() {
        guard legacyTabBarActive else { return }

        legacyTabBar.items = tabBar.items
        legacyTabBar.selectedItem = tabBar.selectedItem
        legacyTabBar.setNeedsDisplay()
    }

    func didLayoutLegacyTabBarIfNeeded() {
        guard legacyTabBarActive else { return }

        let height = legacyTabBar.intrinsicContentSize.height
        tabBarHeightConstraint?.constant = height

        let bottomInset = legacyTabBar.frame.size.height - view.safeAreaInsets.bottom
        for viewController in viewControllers ?? [] {
            viewController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
            if let navigationViewController = viewController as? UINavigationController {
                navigationViewController.delegate = self
            }
        }
    }
}

extension MainTabViewController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        legacyTabBar.isHidden = viewController.hidesBottomBarWhenPushed
    }
}
