/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import InfomaniakDI
import RealmSwift

/// Something to centralize schema versioning
public enum RealmSchemaVersion {
    /// Current version of the Upload Realm
    static let upload: UInt64 = 21

    /// Current version of the Drive Realm
    static let drive: UInt64 = 11
}

public class DriveFileManagerConstants {
    public let driveObjectTypes = [
        File.self,
        Rights.self,
        FileActivity.self,
        FileCategory.self,
        FileConversion.self,
        FileVersion.self,
        FileExternalImport.self,
        ShareLink.self,
        ShareLinkCapabilities.self,
        DropBox.self,
        DropBoxCapabilities.self,
        DropBoxSize.self,
        DropBoxValidity.self
    ]
    private let fileManager = FileManager.default
    public let rootDocumentsURL: URL
    public let importDirectoryURL: URL
    public let groupDirectoryURL: URL
    public var cacheDirectoryURL: URL
    public var tmpDirectoryURL: URL
    public let openInPlaceDirectoryURL: URL?
    public let rootID = 1
    public let currentVersionCode = 1
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

        // Migration for UploadFile renamed initiatedFromFileManager into ownedByFileProvider
        if oldSchemaVersion < 19 {
            migration.enumerateObjects(ofType: UploadFile.className()) { oldObject, newObject in
                guard let newObject else {
                    return
                }

                // Try to migrate the initiatedFromFileManager if possible
                let initiatedFromFileManager: Bool? = oldObject?["initiatedFromFileManager"] as? Bool ?? false
                newObject["ownedByFileProvider"] = initiatedFromFileManager
            }
        }

        // Migration for APIV3
        if oldSchemaVersion < 20 {
            migration.enumerateObjects(ofType: UploadFile.className()) { oldObject, newObject in
                guard let newObject else {
                    return
                }

                newObject["uploadingSession"] = nil
            }
        }
    }

    /// Path of the upload DB
    public lazy var uploadsRealmURL = rootDocumentsURL.appendingPathComponent("uploads.realm")

    public lazy var uploadsRealmConfiguration = Realm.Configuration(
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
        @InjectService var pathProvider: AppGroupPathProvidable
        groupDirectoryURL = pathProvider.groupDirectoryURL
        rootDocumentsURL = pathProvider.realmRootURL
        importDirectoryURL = pathProvider.importDirectoryURL
        tmpDirectoryURL = pathProvider.tmpDirectoryURL
        cacheDirectoryURL = pathProvider.cacheDirectoryURL
        openInPlaceDirectoryURL = pathProvider.openInPlaceDirectoryURL

        DDLogInfo(
            "App working path is: \(fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.absoluteString ?? "")"
        )
        DDLogInfo("Group container path is: \(groupDirectoryURL.absoluteString)")
    }
}
