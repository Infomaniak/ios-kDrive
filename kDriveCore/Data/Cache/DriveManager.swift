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
import InfomaniakDI

public protocol DriveManageable {
    func driveDidSwitch(to drive: Drive, driveFileManager: DriveFileManager, deeplink: Any) async throws
}

public class DriveManager: DriveManageable {
    @LazyInjectService var deeplinkService: DeeplinkServiceable

    public func driveDidSwitch(to drive: Drive, driveFileManager: DriveFileManager, deeplink: Any) async throws {
        try await driveFileManager.initRoot()
        @InjectService var appRestorationService: AppRestorationServiceable
        await appRestorationService.reloadAppUI(for: drive.id, userId: drive.userId)
        deeplinkService.setLastPublicShare(deeplink)
        deeplinkService.processDeeplinksPostAuthentication()
    }
}
