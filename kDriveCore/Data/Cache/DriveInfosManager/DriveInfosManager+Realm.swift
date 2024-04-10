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

public extension DriveInfosManager {
    /// Common way to do a __write__ transaction with the current Realm of the DriveInfosManager
    ///
    /// Protected from sudden termination
    func writeTransaction(withRealm realmClosure: (Realm) throws -> Void) throws {
        try autoreleasepool {
            let expiringActivity = ExpiringActivity()
            expiringActivity.start()
            defer {
                expiringActivity.endAll()
            }

            let realm = getRealm()
            try realm.safeWrite {
                try realmClosure(realm)
            }
        }
    }

    /// Common way to do a read transaction, to fetch one entity, with the current Realm of the DriveInfosManager
    ///
    /// Protected from sudden termination
    ///
    /// NSException thrown if mutating realm elements
    func fetchObject<Element: Object>(ofType type: Element.Type,
                                      withRealm realmClosure: (Realm) -> Element?) -> Element? {
        autoreleasepool {
            let expiringActivity = ExpiringActivity()
            expiringActivity.start()
            defer {
                expiringActivity.endAll()
            }

            let realm = getRealm()
            return realmClosure(realm)
        }
    }

    /// Common way to do a read transaction, to fetch a collection, with the current Realm of the DriveInfosManager
    ///
    /// Protected from sudden termination
    ///
    /// NSException thrown if mutating realm elements
    func fetchResults<Element: RealmFetchable>(ofType type: Element.Type,
                                               withRealm realmClosure: (Realm) -> Results<Element>) -> Results<Element> {
        autoreleasepool {
            let expiringActivity = ExpiringActivity()
            expiringActivity.start()
            defer {
                expiringActivity.endAll()
            }

            let realm = getRealm()
            return realmClosure(realm)
        }
    }

    /// Get an up to date realm for current DriveInfosManager
    ///
    /// This is _not_ protected from sudden termination, prefer `writeTransaction(withRealm:)` method
    private func getRealm() -> Realm {
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
