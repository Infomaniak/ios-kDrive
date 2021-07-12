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

import SnackBar
import UIKit

public enum UIConstants {
    public static let inputCornerRadius: CGFloat = 2
    public static let imageCornerRadius: CGFloat = 3
    public static let cornerRadius: CGFloat = 6
    public static let alertCornerRadius: CGFloat = 8
    public static let buttonCornerRadius: CGFloat = 10
    public static let floatingPanelCornerRadius: CGFloat = 20
    public static let listPaddingBottom: CGFloat = 50
    public static let listFloatingButtonPaddingBottom: CGFloat = 75
    public static let homeListPaddingTop: CGFloat = 16
    public static let floatingPanelHeaderHeight: CGFloat = 70
    public static let largeTitleHeight: CGFloat = 96
    public static let insufficientStorageMinimumPercentage: Double = 90.0

    @discardableResult
    public static func showSnackBar(message: String, duration: SnackBar.Duration = .lengthLong, action: IKSnackBar.Action? = nil) -> IKSnackBar? {
        let snackbar = IKSnackBar.make(message: message, duration: duration)
        if let action = action {
            snackbar?.setAction(action).show()
        } else {
            snackbar?.show()
        }
        return snackbar
    }

    public static func openUrl(_ string: String, from viewController: UIViewController) {
        if let url = URL(string: string) {
            openUrl(url, from: viewController)
        }
    }

    public static func openUrl(_ url: URL, from viewController: UIViewController) {
        #if ISEXTENSION
            viewController.extensionContext?.open(url)
        #else
            UIApplication.shared.open(url)
        #endif
    }

    static func showStore(from viewController: UIViewController, driveFileManager: DriveFileManager) {
        #if ISEXTENSION
        // TODO: Open app
        #else
        let storeViewController = StoreViewController.instantiate(driveFileManager: driveFileManager)
        if let navigationController = viewController.navigationController {
            navigationController.pushViewController(storeViewController, animated: true)
        } else {
            viewController.present(viewController, animated: true)
        }
        #endif
    }
}
