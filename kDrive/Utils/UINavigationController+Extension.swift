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
        navigationBar.layoutMargins.left = 24
        navigationBar.layoutMargins.right = 24
        let navbarAppearance = UINavigationBarAppearance()
        navbarAppearance.configureWithTransparentBackground()
        navbarAppearance.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        let largeTitleStyle = TextStyle.header1
        let titleStyle = TextStyle.header3
        navbarAppearance.largeTitleTextAttributes = [.foregroundColor: largeTitleStyle.color, .font: largeTitleStyle.font]
        navbarAppearance.titleTextAttributes = [.foregroundColor: titleStyle.color, .font: titleStyle.font]
        navigationBar.standardAppearance = navbarAppearance
        navigationBar.compactAppearance = navbarAppearance
        navigationBar.scrollEdgeAppearance = navbarAppearance
    }

    override open var childForStatusBarStyle: UIViewController? {
        return topViewController
    }
}
