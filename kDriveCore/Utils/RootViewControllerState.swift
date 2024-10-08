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

import Foundation
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI

public enum RootViewControllerState {
    case onboarding
    case appLock
    case mainViewController(driveFileManager: DriveFileManager)
    case updateRequired
    case preloading(Account)

    public static func getCurrentState() -> RootViewControllerState {
        @InjectService var accountManager: AccountManageable
        @InjectService var lockHelper: AppLockHelper

        guard let currentAccount = accountManager.currentAccount else {
            return .onboarding
        }

        if UserDefaults.shared.legacyIsFirstLaunch || accountManager.accounts.isEmpty {
            return .onboarding
        } else if UserDefaults.shared.isAppLockEnabled && lockHelper.isAppLocked {
            return .appLock
        } else if let driveFileManager = accountManager.currentDriveFileManager,
                  driveFileManager.getCachedMyFilesRoot() != nil {
            return .mainViewController(driveFileManager: driveFileManager)
        } else {
            return .preloading(currentAccount)
        }
    }
}
