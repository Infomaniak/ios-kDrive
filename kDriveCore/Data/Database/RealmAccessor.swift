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

import CocoaLumberjackSwift
import Foundation
import InfomaniakCoreDB
import RealmSwift

/// Internal structure that can fetch a realm
final class RealmAccessor: RealmAccessible {
    var realmURL: URL
    let realmConfiguration: Realm.Configuration

    init(realmURL: URL, realmConfiguration: Realm.Configuration) {
        self.realmURL = realmURL
        self.realmConfiguration = realmConfiguration
    }

    func getRealm() -> RealmSwift.Realm {
        // Change file metadata after creation of the realm file.
        defer {
            // Exclude "file cache realm" from system backup.
            var metadata = URLResourceValues()
            metadata.isExcludedFromBackup = true
            do {
                try realmURL.setResourceValues(metadata)
            } catch {
                DDLogError(error)
            }
            DDLogInfo("realmURL : \(realmURL)")
        }

        do {
            let realm = try Realm(configuration: realmConfiguration)
            realm.refresh()
            return realm
        } catch {
            // We can't recover from this error but at least we report it correctly on Sentry
            Logging.reportRealmOpeningError(error, realmConfiguration: realmConfiguration)
        }
    }
}
