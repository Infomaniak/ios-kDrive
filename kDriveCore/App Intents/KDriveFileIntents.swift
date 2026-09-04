/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

import AppIntents
import InfomaniakDI
import kDriveResources

@available(iOS 18.0, *)
@AppIntent(schema: .files.openFile)
struct OpenFileIntent: OpenIntent {
    var target: KDriveFileEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        @InjectService var accountManager: AccountManageable
        @InjectService var appNavigable: AppNavigable

        guard let driveFileManager = accountManager.getDriveFileManager(
            for: target.driveId,
            userId: target.userId
        ) else {
            throw DriveError.fileNotFound
        }

        if accountManager.currentUserId != target.userId {
            guard let account = accountManager.account(for: target.userId) else {
                throw DriveError.fileNotFound
            }

            accountManager.switchAccount(newAccount: account)
        }

        if accountManager.currentUserId != target.userId ||
            accountManager.currentDriveId != target.driveId {
            try await driveFileManager.switchDriveAndReloadUI()
        }

        let file = try await driveFileManager.file(
            ProxyFile(driveId: target.driveId, id: target.fileId)
        )

        appNavigable.showMainViewController(driveFileManager: driveFileManager, selectedIndex: 1)
        appNavigable.present(file: file, driveFileManager: driveFileManager, office: false)

        return .result()
    }
}

@available(iOS 18.0, *)
@AppIntent(schema: .files.moveFiles)
struct MoveFilesIntent {
    static var authenticationPolicy: IntentAuthenticationPolicy {
        .requiresLocalDeviceAuthentication
    }

    var entities: [KDriveFileEntity]

    @Parameter(supportedContentTypes: [.folder])
    var destinationFolder: KDriveFileEntity

    func perform() async throws -> some IntentResult {
        let destination = try destinationFolder.resolveCache()

        guard destination.file.isDirectory else {
            throw DriveError.fileNotFound
        }

        guard destination.file.capabilities.canMoveInto else {
            throw DriveError.forbidden
        }

        let moveCoordinator = MoveCoordinator()

        for entity in entities {
            let source = try entity.resolveCache()

            guard source.file.capabilities.canMove else {
                throw DriveError.forbidden
            }

            guard source.file.driveId != destination.file.driveId ||
                source.file.parentId != destination.file.id else {
                continue
            }

            _ = try await moveCoordinator.move(
                file: source.file.proxify(),
                to: destination.file.proxify(),
                sourceDriveFileManager: source.driveFileManager,
                destinationDriveFileManager: destination.driveFileManager
            )
        }

        return .result()
    }
}

@available(iOS 18.0, *)
@AppIntent(schema: .files.renameFile)
struct RenameFileIntent {
    static var authenticationPolicy: IntentAuthenticationPolicy {
        .requiresLocalDeviceAuthentication
    }

    var target: KDriveFileEntity
    var newName: String

    func perform() async throws -> some IntentResult {
        let resolved = try target.resolveCache()

        guard resolved.file.capabilities.canRename else {
            throw DriveError.forbidden
        }

        _ = try await resolved.driveFileManager.rename(file: resolved.file.proxify(), newName: newName)
        return .result()
    }
}

@available(iOS 18.0, *)
@AppIntent(schema: .files.deleteFiles)
struct DeleteFilesIntent: DeleteIntent {
    static var authenticationPolicy: IntentAuthenticationPolicy {
        .requiresLocalDeviceAuthentication
    }

    var entities: [KDriveFileEntity]

    func perform() async throws -> some IntentResult {
        for entity in entities {
            let resolved = try entity.resolveCache()

            guard resolved.file.capabilities.canDelete else {
                throw DriveError.forbidden
            }

            _ = try await resolved.driveFileManager.delete(file: resolved.file.proxify())
        }
        return .result()
    }
}

@available(iOS 18.0, *)
@AppIntent(schema: .files.createFolder)
struct CreateFolderIntent {
    static var authenticationPolicy: IntentAuthenticationPolicy {
        .requiresLocalDeviceAuthentication
    }

    var fileName: String?

    @Parameter(supportedContentTypes: [.folder])
    var target: KDriveFileEntity

    func perform() async throws -> some ReturnsValue<KDriveFileEntity> {
        let folderNameDialog = IntentDialog(
            stringLiteral: KDriveResourcesStrings.Localizable.hintInputDirName
        )
        guard let fileName else {
            throw $fileName.needsValueError(folderNameDialog)
        }

        let folderName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folderName.isEmpty else {
            throw $fileName.needsValueError(folderNameDialog)
        }

        let resolved = try target.resolveCache()

        guard resolved.file.isDirectory,
              resolved.file.capabilities.canCreateDirectory else {
            throw DriveError.forbidden
        }

        let createdFolder = try await resolved.driveFileManager.createDirectory(
            in: resolved.file.proxify(),
            name: folderName,
            onlyForMe: false
        )

        let createdEntity = await KDriveFileEntity.makeEntity(
            for: createdFolder,
            driveFileManager: resolved.driveFileManager
        )

        return .result(value: createdEntity)
    }
}

@available(iOS 18.0, *)
struct ResolvedKDriveFile {
    let file: File
    let driveFileManager: DriveFileManager
}

@available(iOS 18.0, *)
extension KDriveFileEntity {
    func resolveCache() throws -> ResolvedKDriveFile {
        @InjectService var accountManager: AccountManageable

        guard let driveFileManager = accountManager.getDriveFileManager(
            for: driveId,
            userId: userId
        ),
            let file = driveFileManager.getCachedFile(id: fileId) else {
            throw DriveError.fileNotFound
        }

        return ResolvedKDriveFile(
            file: file,
            driveFileManager: driveFileManager
        )
    }
}
