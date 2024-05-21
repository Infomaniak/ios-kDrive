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
import os.log
import UIKit

/// Something that loads the DI on init
public struct EarlyDIHook {
    public init(context: DriveAppContext) {
        os_log("EarlyDIHook")

        let extraDependencies = [
            Factory(type: NavigationManageable.self) { _, _ in
                NavigationManager()
            },
            Factory(type: AppContextServiceable.self) { _, _ in
                AppContextService(context: context)
            },
            Factory(type: AppRestorationService.self) { _, _ in
                AppRestorationService()
            }
        ]

        // setup DI ASAP
        FactoryService.setupDependencyInjection(other: extraDependencies)
    }
}

// TODO: Refactor with Scenes / NSUserActivity
#if !ISEXTENSION

public final class AppRestorationService {
    /// Path where the state restoration state is saved
    private static let statePath = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)
        .first?
        .appendingPathComponent("Saved Application State")

    @LazyInjectService private var accountManager: AccountManageable

    /// State restoration version
    private static let currentStateVersion = 4

    /// State restoration key
    private static let appStateVersionKey = "appStateVersionKey"

    public init() {
        // META: keep SonarCloud happy
    }

    public func shouldSaveApplicationState(coder: NSCoder) -> Bool {
        Log.appDelegate("shouldSaveApplicationState")
        Log.appDelegate("Restoration files:\(String(describing: Self.statePath))")
        coder.encode(Self.currentStateVersion, forKey: Self.appStateVersionKey)
        return true
    }

    public func shouldRestoreApplicationState(coder: NSCoder) -> Bool {
        let encodedVersion = coder.decodeInteger(forKey: Self.appStateVersionKey)
        let shouldRestoreApplicationState = Self.currentStateVersion == encodedVersion &&
            !(UserDefaults.shared.legacyIsFirstLaunch || accountManager.accounts.isEmpty)
        Log.appDelegate("shouldRestoreApplicationState:\(shouldRestoreApplicationState)")
        return shouldRestoreApplicationState
    }

    public func respring(drive: Drive) {
        @InjectService var accountManager: AccountManageable
        accountManager.setCurrentDriveForCurrentAccount(drive: drive)
        accountManager.saveAccounts()

        guard let currentDriveFileManager = accountManager.currentDriveFileManager else {
            return
        }

        // Read the last tab selected in order to properly respring.
        // This should be migrated to NSUserActivity at some point
        let lastSelectedTab = UserDefaults.shared.lastSelectedTab
        let newMainTabViewController = MainTabViewController(
            driveFileManager: currentDriveFileManager,
            selectedIndex: lastSelectedTab
        )
        (UIApplication.shared.delegate as? AppDelegate)?.setRootViewController(newMainTabViewController)

        // cleanup
        UserDefaults.shared.lastSelectedTab = nil
    }
}

#else

public final class AppRestorationService {
    public init() {
        // META: keep SonarCloud happy
    }

    public func shouldSaveApplicationState(coder: NSCoder) -> Bool {
        false
    }

    public func shouldRestoreApplicationState(coder: NSCoder) -> Bool {
        false
    }

    public func respring(drive: Drive) {
        // NOOP
    }
}

#endif
