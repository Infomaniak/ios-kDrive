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

import UIKit
import kDriveCore

extension UINavigationController {

    func setTransparentStandardAppearanceNavigationBar() {
        if #available(iOS 13.0, *) {
            let navbarAppearance = UINavigationBarAppearance()
            navbarAppearance.configureWithTransparentBackground()
            navbarAppearance.shadowImage = UIImage()
            self.navigationBar.standardAppearance = navbarAppearance
            self.navigationBar.compactAppearance = navbarAppearance
            self.navigationBar.scrollEdgeAppearance = navbarAppearance
        } else {
            self.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
            self.navigationBar.shadowImage = UIImage()
        }
    }

    func setDefaultStandardAppearanceNavigationBar() {
        if #available(iOS 13.0, *) {
            let navbarAppearance = UINavigationBarAppearance()
            navbarAppearance.configureWithDefaultBackground()
            self.navigationBar.standardAppearance = navbarAppearance
            self.navigationBar.compactAppearance = navbarAppearance
            self.navigationBar.scrollEdgeAppearance = navbarAppearance
        } else {
            self.navigationBar.setBackgroundImage(nil, for: UIBarMetrics.default)
            self.navigationBar.shadowImage = nil
        }
    }

    func setInfomaniakAppearanceNavigationBar() {
        navigationBar.layoutMargins.left = 24
        navigationBar.layoutMargins.right = 24
        if #available(iOS 13.0, *) {
            let navbarAppearance = UINavigationBarAppearance()
            navbarAppearance.configureWithTransparentBackground()
            navbarAppearance.backgroundColor = KDriveAsset.backgroundColor.color
            let largeTitleStyle = TextStyle.header1
            let titleStyle = TextStyle.header3
            navbarAppearance.largeTitleTextAttributes = [.foregroundColor: largeTitleStyle.color, .font: largeTitleStyle.font]
            navbarAppearance.titleTextAttributes = [.foregroundColor: titleStyle.color, .font: titleStyle.font]
            self.navigationBar.standardAppearance = navbarAppearance
            self.navigationBar.compactAppearance = navbarAppearance
            self.navigationBar.scrollEdgeAppearance = navbarAppearance
        } else {
            self.navigationBar.isTranslucent = false
            self.navigationBar.barTintColor = KDriveAsset.backgroundColor.color
            self.navigationBar.shadowImage = UIImage()
        }
    }

    open override var childForStatusBarStyle: UIViewController? {
        return topViewController
    }

}
