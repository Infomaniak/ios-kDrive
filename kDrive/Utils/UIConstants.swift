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

class UIConstants {
    static let inputCornerRadius: CGFloat = 2
    static let imageCornerRadius: CGFloat = 3
    static let cornerRadius: CGFloat = 6
    static let alertCornerRadius: CGFloat = 8
    static let buttonCornerRadius: CGFloat = 10
    static let floatingPanelCornerRadius: CGFloat = 20
    static let listPaddingBottom: CGFloat = 50
    static let listFloatingButtonPaddingBottom: CGFloat = 75
    static let homeListPaddingTop: CGFloat = 16
    static let floatingPanelHeaderHeight: CGFloat = 70
    static let largeTitleHeight: CGFloat = 96
    static let insufficientStorageMinimumPercentage: Double = 90.0
    static let swipeActionShareIdentifier = "share"
    static let swipeActionMoreIdentifier = "more"
    static let swipeActionDeleteIdentifier = "delete"

    static func showSnackBar(message: String, view: UIView? = nil) {
        InfomaniakSnackBar.make(message: message, duration: .lengthLong, view: view)?.show()
    }

    static func showSnackBarWithAction(message: String, view: UIView? = nil, action: String, completion: @escaping () -> Void) {
        InfomaniakSnackBar.make(message: message, duration: .lengthLong, view: view, action: action, completion: completion)?.show()
    }

    static func openUrl(_ string: String, from viewController: UIViewController) {
        if let url = URL(string: string) {
            openUrl(url, from: viewController)
        }
    }

    static func openUrl(_ url: URL, from viewController: UIViewController) {
        #if ISEXTENSION
            viewController.extensionContext?.open(url)
        #else
            UIApplication.shared.open(url)
        #endif
    }
}
