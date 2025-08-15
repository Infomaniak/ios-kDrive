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
import InfomaniakDI
import kDriveCore
import UIKit

public final class AppRestorationService: AppRestorationServiceable {
    @LazyInjectService var appNavigable: AppNavigable

    /// Path where the state restoration state is saved
    private static let statePath = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)
        .first?
        .appendingPathComponent("Saved Application State")

    @LazyInjectService private var accountManager: AccountManageable
    @LazyInjectService private var appContextService: AppContextServiceable

    /// State restoration version
    private static let currentStateVersion = 5

    public init() {
        // META: keep SonarCloud happy
    }

    public var shouldSaveApplicationState: Bool {
        Log.sceneDelegate("shouldSaveApplicationState")
        Log.sceneDelegate("Restoration files:\(String(describing: Self.statePath))")

        return true
    }

    public var shouldRestoreApplicationState: Bool {
        guard !appContextService.isExtension else {
            return false
        }

        let storedVersion = UserDefaults.shared.appRestorationVersion
        let shouldRestore = Self.currentStateVersion == storedVersion &&
            !(UserDefaults.shared.legacyIsFirstLaunch || accountManager.accounts.isEmpty)

        Log.sceneDelegate(
            "shouldRestoreApplicationState:\(shouldRestore) appRestorationVersion:\(String(describing: storedVersion))"
        )
        return shouldRestore
    }

    public func saveRestorationVersion() {
        UserDefaults.shared.appRestorationVersion = Self.currentStateVersion
        Log.sceneDelegate("saveRestorationVersion to \(Self.currentStateVersion)")
    }

    public func reloadAppUI(for driveId: Int, userId: Int) async {
        accountManager.setCurrentDriveForCurrentAccount(for: driveId, userId: userId)
        accountManager.saveAccounts()

        guard let currentDriveFileManager = accountManager.currentDriveFileManager else {
            return
        }

        // Read the last tab selected in order to properly reload the App's UI.
        let lastSelectedTab = UserDefaults.shared.lastSelectedTab

        await appNavigable.showMainViewController(driveFileManager: currentDriveFileManager, selectedIndex: lastSelectedTab)
    }
}
