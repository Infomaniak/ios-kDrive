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

public class DriveCapabilities: EmbeddedObject, Codable {
    @Persisted public var useVersioning = false
    @Persisted public var useUploadCompression = false
    @Persisted public var useTeamSpace = false
    @Persisted public var canAddUser = false
    @Persisted public var canSeeStats = false
    @Persisted public var canUpgradeToKsuite = false
    @Persisted public var canRewind = false
}
