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

import InfomaniakDI
import SwiftUI

public struct DeeplinkParser {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var navigationManager: NavigationManageable

    private let window: UIWindow?

    public init(window: UIWindow?) {
        self.window = window
    }

    public func parse(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let params = components.queryItems else {
            Log.appDelegate("Failed to open URL: Invalid URL", level: .error)
            return false
        }

        if components.path == "store",
           let userId = params.first(where: { $0.name == "userId" })?.value,
           let driveId = params.first(where: { $0.name == "driveId" })?.value {
            if var viewController = window?.rootViewController,
               let userId = Int(userId), let driveId = Int(driveId),
               let driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId) {
                // Get presented view controller
                while let presentedViewController = viewController.presentedViewController {
                    viewController = presentedViewController
                }
                // Show store
                navigationManager.showStore(from: viewController, driveFileManager: driveFileManager)
            }
            return true
        } else if components.host == "file",
                  let filePath = params.first(where: { $0.name == "url" })?.value {
            let fileUrl = URL(fileURLWithPath: filePath)
            if let driveFileManager = accountManager.currentDriveFileManager,
               var viewController = window?.rootViewController {
                while let presentedViewController = viewController.presentedViewController {
                    viewController = presentedViewController
                }
                let file = ImportedFile(name: fileUrl.lastPathComponent, path: fileUrl, uti: fileUrl.uti ?? .data)
                navigationManager.showSaveFileVC(from: viewController, driveFileManager: driveFileManager, file: file)
            }
            return true
        }
        return false
    }
}
