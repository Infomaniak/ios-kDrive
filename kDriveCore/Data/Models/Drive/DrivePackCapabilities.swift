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
import RealmSwift

public class DrivePackCapabilities: EmbeddedObject, Codable {
    @Persisted public var useVault = false
    @Persisted public var useManageRight = false
    @Persisted public var canSetTrashDuration = false
    @Persisted public var useDropbox = false
    @Persisted public var canRewind = false
    @Persisted public var useFolderCustomColor = false
    @Persisted public var canAccessDashboard = false
    @Persisted public var canSetSharelinkPassword = false
    @Persisted public var canSetSharelinkExpiration = false
    @Persisted public var canSetSharelinkCustomUrl = false

    enum CodingKeys: String, CodingKey {
        case useVault = "use_vault"
        case useManageRight = "use_manage_right"
        case canSetTrashDuration = "can_set_trash_duration"
        case useDropbox = "use_dropbox"
        case canRewind = "can_rewind"
        case useFolderCustomColor = "use_folder_custom_color"
        case canAccessDashboard = "can_access_dashboard"
        case canSetSharelinkPassword = "can_set_sharelink_password"
        case canSetSharelinkExpiration = "can_set_sharelink_expiration"
        case canSetSharelinkCustomUrl = "can_set_sharelink_custom_url"
    }
}
