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
import InfomaniakCoreDB
import RealmSwift

/// Shared protected DB transaction code.
struct TransactionExecutor: Transactionable {
    let realmAccessible: RealmAccessible

    func writeTransaction(withRealm realmClosure: (Realm) throws -> Void) throws {
        try autoreleasepool {
            let expiringActivity = ExpiringActivity()
            expiringActivity.start()
            defer {
                expiringActivity.endAll()
            }

            let realm = realmAccessible.getRealm()
            try realm.safeWrite {
                try realmClosure(realm)
            }
        }
    }

    func fetchObject<Element: Object>(ofType type: Element.Type,
                                      withRealm realmClosure: (Realm) -> Element?) -> Element? {
        autoreleasepool {
            let expiringActivity = ExpiringActivity()
            expiringActivity.start()
            defer {
                expiringActivity.endAll()
            }

            let realm = realmAccessible.getRealm()
            return realmClosure(realm)
        }
    }

    func fetchResults<Element: RealmFetchable>(ofType type: Element.Type,
                                               withRealm realmClosure: (Realm) -> Results<Element>) -> Results<Element> {
        autoreleasepool {
            let expiringActivity = ExpiringActivity()
            expiringActivity.start()
            defer {
                expiringActivity.endAll()
            }

            let realm = realmAccessible.getRealm()
            return realmClosure(realm)
        }
    }
}
