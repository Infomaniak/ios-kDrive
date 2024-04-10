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
import RealmSwift

// TODO: Move to Core DB
/// Something that can access a realm
///
/// For compatibility only, prefer { RealmConfigurable + Transactionable } conformance in your app
///
public protocol RealmAccessible {
    /// Fetches an up to date realm for a given configuration, or fail in a controlled manner
    func getRealm() -> Realm
}

// TODO: Move to Core DB
/// Something that can access a realm configuration
public protocol RealmConfigurable {
    /// Configuration for a given realm
    var realmConfiguration: Realm.Configuration { get }

    /// Set `isExcludedFromBackup = true`  to the folder where realm is located to exclude a realm cache from an iCloud backup
    /// - Important: Avoid calling this method too often as this can be expensive, prefer calling it once at init time
    func excludeRealmFromBackup()
}

// TODO: Move to Core DB
/// Something that standardises the transactions API, on a specific realm.
public protocol Transactionable {
    /// Provides a writable realm within a closure. Forwards swift errors.
    /// - Parameter realmClosure: The closure to put the transaction into
    func writeTransaction(withRealm realmClosure: (Realm) throws -> Void) throws

    /// Fetches one object form a realm. Closure style can adapt to existing code.
    ///
    /// The realm is never writable, will throw if mutation occurs within `realmClosure`
    ///
    /// - Parameters:
    ///   - type: The type of the object queried. Defines the return type.
    ///   - realmClosure:  The closure to put the fetch, filter, sort operations
    /// - Returns: A matched entity if any
    func fetchObject<Element: Object>(ofType type: Element.Type,
                                      withRealm realmClosure: (Realm) -> Element?) -> Element?

    /// Fetches a faulted realm collection. Closure style can adapt to existing code.
    ///
    /// The realm is never writable, will throw if mutation occurs within `realmClosure`
    ///
    /// - Parameters:
    ///   - type: The type of the object queried. Defines the return type.
    ///   - realmClosure: The closure to put the fetch, filter, sort operations
    /// - Returns: A faulted realm collection.
    func fetchResults<Element: RealmFetchable>(ofType type: Element.Type,
                                               withRealm realmClosure: (Realm) -> Results<Element>) -> Results<Element>
}

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

public extension DriveFileManager {
    /// Common way to do a __write__ transaction with the current Realm of the DriveFileManager
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

    /// Common way to do a read transaction, to fetch one entity, with the current Realm of the DriveFileManager
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

    /// Common way to do a read transaction, to fetch a collection, with the current Realm of the DriveFileManager
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

    /// Get an up to date realm for current DriveFileManager
    ///
    /// This is _not_ protected from sudden termination, prefer `transaction(withRealm:)` method
    private func getRealm() -> Realm {
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
