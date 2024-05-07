/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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
import InfomaniakCore
import InfomaniakCoreDB
import RealmSwift
import Sentry

/// So we can directly call Transactionable API on top of UploadOperation
extension BackgroundRealm: TransactionablePassthrough {}

// TODO: Remove
public final class BackgroundRealm {
    private struct WriteOperation: Equatable, Hashable {
        let parent: File?
        let file: File

        func hash(into hasher: inout Hasher) {
            if let parentId = parent?.id {
                hasher.combine(parentId)
            }
            hasher.combine(file.id)
        }

        static func == (lhs: WriteOperation, rhs: WriteOperation) -> Bool {
            return lhs.parent?.id == rhs.parent?.id
                && lhs.file.id == rhs.file.id
                && lhs.file.lastModifiedAt == rhs.file.lastModifiedAt
        }
    }

    public static let uploads = instanceOfBackgroundRealm(for: DriveFileManager.constants.uploadsRealmConfiguration)
    private static var instances = SendableDictionary<String, BackgroundRealm>()

    /// Something to centralize transaction style access to the DB
    let transactionExecutor: Transactionable

    public class func instanceOfBackgroundRealm(for configuration: Realm.Configuration) -> BackgroundRealm {
        guard let fileURL = configuration.fileURL else {
            fatalError("Realm configurations without file URL not supported")
        }

        if let instance = instances[fileURL.absoluteString] {
            return instance
        } else {
            let instance = BackgroundRealm(realmConfiguration: configuration)
            instances[fileURL.absoluteString] = instance
            return instance
        }
    }

    private init(realmConfiguration: Realm.Configuration) {
        let realmAccessor = RealmAccessor(realmURL: realmConfiguration.fileURL,
                                          realmConfiguration: realmConfiguration,
                                          excludeFromBackup: true)
        transactionExecutor = TransactionExecutor(realmAccessible: realmAccessor)
    }

    public func execute(_ block: (Realm) -> Void) {
        // No need to use queue.sync as a new realm is used every time
        try? writeTransaction { writableRealm in
            block(writableRealm)
        }
    }
}
