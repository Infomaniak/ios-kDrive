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

// TODO: Move to Core
/// Something that can access a realm with a given configuration
public protocol RealmAccessible {
    /// Configuration for a given realm
    var realmConfiguration: Realm.Configuration { get }

    /// Fetches an up to date realm for a given configuration, or fail in a controlled manner
    func getRealm() -> Realm

    /// Set `isExcludedFromBackup = true`  to the folder where realm is located to exclude a realm cache from an iCloud backup
    /// - Important: Avoid calling this method too often as this can be expensive, prefer calling it once at init time
    func excludeRealmFromBackup()
}
