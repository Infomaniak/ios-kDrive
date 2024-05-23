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

import UIKit

extension AppDelegate {
    // For non-scene-based versions of this app on iOS 13.1 and earlier.
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return appRestorationService.shouldSaveApplicationState(coder: coder)
    }

    // For non-scene-based versions of this app on iOS 13.1 and earlier.
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return appRestorationService.shouldRestoreApplicationState(coder: coder)
    }

    @available(iOS 13.2, *)
    // For non-scene-based versions of this app on iOS 13.2 and later.
    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        return appRestorationService.shouldSaveApplicationState(coder: coder)
    }

    @available(iOS 13.2, *)
    // For non-scene-based versions of this app on iOS 13.2 and later.
    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        return appRestorationService.shouldRestoreApplicationState(coder: coder)
    }
}
