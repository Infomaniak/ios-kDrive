/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

public class PhotoUploadQueue: UploadQueue {
    /// Should suspend operation queue based on network status and user defined parameters
    override var shouldSuspendQueue: Bool {
        // Explicitly disable the upload queue from the share extension
        guard appContextService.context != .shareExtension else {
            return true
        }

        let status = ReachabilityListener.instance.currentStatus
        let shouldBeSuspended = status == .offline || (status != .wifi && UserDefaults.shared.isWifiOnly)
        return shouldBeSuspended
    }
}
