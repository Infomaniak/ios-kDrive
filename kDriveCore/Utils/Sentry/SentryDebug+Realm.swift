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
import Sentry

// MARK: - REALM Migration

extension SentryDebug {
    static func realmMigrationStartedBreadcrumb(form: UInt64, to: UInt64, realmName: String, function: String = #function) {
        realmMigrationBreadcrumb(state: .start, form: form, to: to, realmName: realmName, function: function)
    }

    static func realmMigrationEndedBreadcrumb(form: UInt64, to: UInt64, realmName: String, function: String = #function) {
        realmMigrationBreadcrumb(state: .end, form: form, to: to, realmName: realmName, function: function)
    }

    enum MigrationState: String {
        case start
        case end
    }

    private static func realmMigrationBreadcrumb(
        state: MigrationState,
        form: UInt64,
        to: UInt64,
        realmName: String,
        function: String
    ) {
        let metadata: [String: Any] = ["sate": state.rawValue,
                                       "realmName": realmName,
                                       "form": form,
                                       "to": to,
                                       "function": function]
        Self.addBreadcrumb(message: Category.realmMigration.rawValue, category: .realmMigration, level: .info, metadata: metadata)
    }
}
