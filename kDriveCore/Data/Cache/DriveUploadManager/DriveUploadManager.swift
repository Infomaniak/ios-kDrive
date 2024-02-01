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

import Alamofire
import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import InfomaniakDI
import InfomaniakLogin
import RealmSwift
import SwiftRegex

/// Handle the realm db used for file upload
public final class DriveUploadManager: RealmAccessible {
    private let fileManager = FileManager.default

    // TODO: Use DI
    public static let constants = DriveConstants()

    public lazy var migrationBlock = { [weak self] (migration: Migration, oldSchemaVersion: UInt64) in
        let currentUploadSchemaVersion = RealmSchemaVersion.upload

        // Log migration on Sentry
        SentryDebug.realmMigrationStartedBreadcrumb(
            form: oldSchemaVersion,
            to: currentUploadSchemaVersion,
            realmName: "Upload"
        )
        defer {
            SentryDebug.realmMigrationEndedBreadcrumb(
                form: oldSchemaVersion,
                to: currentUploadSchemaVersion,
                realmName: "Upload"
            )
        }

        // Sanity check
        guard oldSchemaVersion < currentUploadSchemaVersion else {
            return
        }

        // Migration from version 2 to version 3
        if oldSchemaVersion < 3 {
            migration.enumerateObjects(ofType: UploadFile.className()) { _, newObject in
                newObject!["maxRetryCount"] = 3
            }
        }
        // Migration to version 4 -> 7 is not needed
        // Migration from version 7 to version 9
        if oldSchemaVersion < 9 {
            migration.deleteData(forType: DownloadTask.className())
        }

        // Migration from version 9 to version 10
        if oldSchemaVersion < 10 {
            migration.enumerateObjects(ofType: UploadFile.className()) { _, newObject in
                newObject!["conflictOption"] = ConflictOption.version.rawValue
            }
        }

        if oldSchemaVersion < 12 {
            migration.enumerateObjects(ofType: PhotoSyncSettings.className()) { _, newObject in
                newObject!["photoFormat"] = PhotoFileFormat.heic.rawValue
            }
        }

        // Migration for Upload With Chunks
        if oldSchemaVersion < 14 {
            migration.deleteData(forType: UploadFile.className())
        }

        // Migration for UploadFile With dedicated fileProviderItemIdentifier and assetLocalIdentifier fields
        if oldSchemaVersion < 15 {
            migration.enumerateObjects(ofType: UploadFile.className()) { oldObject, newObject in
                guard let newObject else {
                    return
                }

                // Try to migrate the assetLocalIdentifier if possible
                let type: String? = oldObject?["rawType"] as? String ?? nil

                switch type {
                case UploadFileType.phAsset.rawValue:
                    // The object was from a phAsset source, the id has to be the `LocalIdentifier`
                    let oldAssetIdentifier: String? = oldObject?["id"] as? String ?? nil

                    newObject["assetLocalIdentifier"] = oldAssetIdentifier
                    newObject["fileProviderItemIdentifier"] = nil

                    // Making sure the ID is unique, and not a PHAsset identifier
                    newObject["id"] = UUID().uuidString

                default:
                    // We cannot infer anything, all to nil
                    newObject["assetLocalIdentifier"] = nil
                    newObject["fileProviderItemIdentifier"] = nil
                }
            }
        }
    }

    /// Path of the upload DB
    public lazy var uploadsRealmURL = DriveUploadManager.constants.rootDocumentsURL.appendingPathComponent("uploads.realm")

    public lazy var realmConfiguration = Realm.Configuration(
        fileURL: uploadsRealmURL,
        schemaVersion: RealmSchemaVersion.upload,
        migrationBlock: migrationBlock,
        objectTypes: [DownloadTask.self,
                      PhotoSyncSettings.self,
                      UploadSession.self,
                      UploadFile.self,
                      UploadingChunkTask.self,
                      UploadedChunk.self,
                      UploadingSessionTask.self]
    )

    init() {
        // META: keep SonarCloud happy
    }
}
