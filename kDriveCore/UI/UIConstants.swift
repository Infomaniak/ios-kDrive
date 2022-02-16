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

import kDriveResources
import SnackBar
import UIKit

public enum UIConstants {
    public static let inputCornerRadius = 2.0
    public static let imageCornerRadius = 3.0
    public static let cornerRadius = 6.0
    public static let alertCornerRadius = 8.0
    public static let buttonCornerRadius = 10.0
    public static let floatingPanelCornerRadius = 20.0
    public static let listPaddingBottom = 50.0
    public static let listFloatingButtonPaddingBottom = 75.0
    public static let homeListPaddingTop = 16.0
    public static let floatingPanelHeaderHeight = 70.0
    public static let fileListCellHeight = 60.0
    public static let largeTitleHeight = 96.0
    public static let insufficientStorageMinimumPercentage = 90.0
    public static let dropDelay = -1.0

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

    @discardableResult
    public static func showCancelableSnackBar(message: String, cancelSuccessMessage: String, duration: SnackBar.Duration = .lengthLong, cancelableResponse: CancelableResponse, parentFile: File?, driveFileManager: DriveFileManager) -> IKSnackBar? {
        return UIConstants.showSnackBar(message: message, duration: duration, action: .init(title: KDriveResourcesStrings.Localizable.buttonCancel) {
            Task {
                do {
                    let now = Date()
                    try await driveFileManager.undoAction(cancelId: cancelableResponse.id)
                    if let parentFile = parentFile {
                        _ = try? await driveFileManager.fileActivities(file: parentFile, from: Int(now.timeIntervalSince1970))
                    }

                    _ = await MainActor.run {
                        UIConstants.showSnackBar(message: cancelSuccessMessage)
                    }
                } catch {
                    _ = await MainActor.run {
                        UIConstants.showSnackBar(message: error.localizedDescription)
                    }
                }
            }
        })
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
}
