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

/// Wrapping the DriveFileManager context and the linked Realm DB together
public enum DriveFileManagerContext {
    /// Main app dataset
    case drive

    /// Dedicated dataset to store the state of files in the FileProvider
    case fileProvider

    /// Dedicated dataset to store shared with me
    case sharedWithMe

    func realmURL(using drive: Drive) -> URL {
        switch self {
        case .drive:
            return DriveFileManager.constants.rootDocumentsURL.appendingPathComponent("\(drive.userId)-\(drive.id).realm")
        case .sharedWithMe:
            return DriveFileManager.constants.rootDocumentsURL.appendingPathComponent("\(drive.userId)-shared.realm")
        case .fileProvider:
            return DriveFileManager.constants.rootDocumentsURL.appendingPathComponent("\(drive.userId)-\(drive.id)-fp.realm")
        }
    }
}

// MARK: - Transactionable

public extension DriveFileManager {
    func fetchObject<Element: Object, KeyType>(ofType type: Element.Type,
                                               forPrimaryKey key: KeyType) -> Element? {
        return transactionExecutor.fetchObject(ofType: type, forPrimaryKey: key)
    }

    func fetchObject<Element: RealmFetchable>(ofType type: Element.Type,
                                              filtering: (Results<Element>) -> Element?) -> Element? {
        return transactionExecutor.fetchObject(ofType: type, filtering: filtering)
    }

    func fetchResults<Element: RealmFetchable>(ofType type: Element.Type,
                                               filtering: (Results<Element>) -> Results<Element>) -> Results<Element> {
        return transactionExecutor.fetchResults(ofType: type, filtering: filtering)
    }

    func writeTransaction(withRealm realmClosure: (Realm) throws -> Void) throws {
        try transactionExecutor.writeTransaction(withRealm: realmClosure)
    }
}
