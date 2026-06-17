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

import InfomaniakCoreCommonUI
import kDriveCore
import kDriveResources
import UIKit

extension UINavigationController {
    func setTransparentStandardAppearanceNavigationBar() {
        let navbarAppearance = UINavigationBarAppearance()
        navbarAppearance.configureWithTransparentBackground()
        navbarAppearance.shadowImage = UIImage()
        navigationBar.standardAppearance = navbarAppearance
        navigationBar.compactAppearance = navbarAppearance
        navigationBar.scrollEdgeAppearance = navbarAppearance
    }

    func setDefaultStandardAppearanceNavigationBar() {
        let navbarAppearance = UINavigationBarAppearance()
        navbarAppearance.configureWithDefaultBackground()
        navigationBar.standardAppearance = navbarAppearance
        navigationBar.compactAppearance = navbarAppearance
        navigationBar.scrollEdgeAppearance = navbarAppearance
    }

    func setInfomaniakAppearanceNavigationBar() {
        let shouldApplyCustomMargins: Bool

        if #available(iOS 26.0, *) {
            shouldApplyCustomMargins = UIDevice.current.userInterfaceIdiom != .pad
        } else {
            shouldApplyCustomMargins = true
        }

        if shouldApplyCustomMargins {
            navigationBar.layoutMargins.right = 24
        }

        navigationBar.layoutMargins.left = 24
        let largeTitleStyle = TextStyle.header1
        let titleStyle = TextStyle.header3

        if #available(iOS 26.0, *) {
            let standardAppearance = UINavigationBarAppearance()
            standardAppearance.configureWithDefaultBackground()
            standardAppearance.backgroundColor = KDriveResourcesAsset.backgroundColor.color
            standardAppearance.largeTitleTextAttributes = [.foregroundColor: largeTitleStyle.color, .font: largeTitleStyle.font]
            standardAppearance.titleTextAttributes = [.foregroundColor: titleStyle.color, .font: titleStyle.font]

            let scrollEdgeAppearance = UINavigationBarAppearance()
            scrollEdgeAppearance.configureWithTransparentBackground()
            scrollEdgeAppearance.largeTitleTextAttributes = [.foregroundColor: largeTitleStyle.color, .font: largeTitleStyle.font]
            scrollEdgeAppearance.titleTextAttributes = [.foregroundColor: titleStyle.color, .font: titleStyle.font]

            navigationBar.standardAppearance = standardAppearance
            navigationBar.compactAppearance = standardAppearance
            navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        } else {
            let navbarAppearance = UINavigationBarAppearance()
            navbarAppearance.configureWithTransparentBackground()
            navbarAppearance.backgroundColor = KDriveResourcesAsset.backgroundColor.color
            navbarAppearance.largeTitleTextAttributes = [.foregroundColor: largeTitleStyle.color, .font: largeTitleStyle.font]
            navbarAppearance.titleTextAttributes = [.foregroundColor: titleStyle.color, .font: titleStyle.font]
            navigationBar.standardAppearance = navbarAppearance
            navigationBar.compactAppearance = navbarAppearance
            navigationBar.scrollEdgeAppearance = navbarAppearance
        }
    }

    override open var childForStatusBarStyle: UIViewController? {
        return topViewController
    }
}
