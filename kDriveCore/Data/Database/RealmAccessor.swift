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

/// Something to identify specific instances of Transactionable
public enum kDriveDBID {
    /// Identifier of the Transactionable object that manages UploadFiles
    public static let uploads = "uploads"

    /// Identifier of the Transactionable object that manages Drive
    public static let driveInfo = "driveInfo"
}

/// Internal structure that can fetch a realm
final class RealmAccessor: RealmAccessible {
    var realmURL: URL?
    let realmConfiguration: Realm.Configuration
    var excludeFromBackup: Bool

    init(realmURL: URL?, realmConfiguration: Realm.Configuration, excludeFromBackup: Bool) {
        self.realmURL = realmURL
        self.realmConfiguration = realmConfiguration
        self.excludeFromBackup = excludeFromBackup
    }

    func getRealm() -> Realm {
        getRealm(canRetry: true)
    }

    private func getRealm(canRetry: Bool) -> Realm {
        defer {
            // Change file metadata after creation of the realm file.
            excludeFromBackupIfNeeded()
        }

        do {
            let realm = try Realm(configuration: realmConfiguration)
            realm.refresh()
            return realm
        } catch let error as RLMError where error.code == .fail || error.code == .schemaMismatch {
            Logging.reportRealmOpeningError(error, realmConfiguration: realmConfiguration)

            #if DEBUG
            Logger.general.error("Realm files will be deleted, you can resume the app with the debugger")
            // This will force the execution to breakpoint, to give a chance to the dev for debugging
            raise(SIGINT)
            #endif

            _ = try? Realm.deleteFiles(for: realmConfiguration)

            return getRealm(canRetry: false)
        } catch {
            Logging.reportRealmOpeningError(error, realmConfiguration: realmConfiguration)

            guard canRetry else {
                fatalError("Failed creating realm after a retry \(error.localizedDescription)")
            }

            return getRealm(canRetry: false)
        }
    }

    private func excludeFromBackupIfNeeded() {
        guard excludeFromBackup else {
            return
        }

        // Only perform the exclusion once, after we are sure the realm file exists on the FS.
        excludeFromBackup = false

        guard var realmURL else {
            DDLogError("not realmURL to work with")
            return
        }

        // Exclude "file cache realm" from system backup.
        var metadata = URLResourceValues()
        metadata.isExcludedFromBackup = true

        do {
            try realmURL.setResourceValues(metadata)
            DDLogInfo("Excluding realm URL from backup: \(realmURL)")
        } catch {
            DDLogError("Error excluding realm URL from backup: \(realmURL) \(error)")
        }
    }
}
