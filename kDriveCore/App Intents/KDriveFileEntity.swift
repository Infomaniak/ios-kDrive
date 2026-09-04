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
import CoreSpotlight
import FileProvider
import Foundation
import InfomaniakDI
import UniformTypeIdentifiers

@available(iOS 18.4, *)
@AppEntity(schema: .files.file)
struct KDriveFileEntity: IndexedEntity {
    static func spotlightDomainIdentifier(
        userId: Int,
        driveId: Int
    ) -> String {
        "kdrive-user-\(userId)-drive-\(driveId)"
    }

    private static let maximumResultCount = 25

    static let defaultQuery = KDriveEntityQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("itemLabel", table: "Localizable")
        )
    }

    static let supportedContentTypes: [UTType] = [.item, .folder]

    var id: FileEntityIdentifier

    @Property(indexingKey: \.contentCreationDate)
    var creationDate: Date?

    @Property(indexingKey: \.contentModificationDate)
    var fileModificationDate: Date?

    @Property(indexingKey: \.contentType)
    var contentTypeIdentifier: String

    @Property(indexingKey: \.keywords)
    var categoryNames: [String]

    @Property(indexingKey: \.displayName)
    var name: String

    var objectId: String
    var userId: Int
    var driveId: Int
    var fileId: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)"
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .item)

        set.title = name
        set.displayName = name
        set.keywords = categoryNames
        set.contentType = contentTypeIdentifier
        set.contentCreationDate = creationDate
        set.contentModificationDate = fileModificationDate

        set.domainIdentifier = Self.spotlightDomainIdentifier(userId: userId, driveId: driveId)

        return set
    }

    init(file: File, userId: Int, fileProviderURL: URL) throws {
        try self.init(file: file, userId: userId, id: .file(url: fileProviderURL))
    }

    static func makeEntity(
        for file: File,
        driveFileManager: DriveFileManager
    ) async -> KDriveFileEntity {
        let domains = (try? await NSFileProviderManager.domains()) ?? []

        let manager = domains
            .first { $0.identifier.rawValue == driveFileManager.drive.objectId }
            .flatMap { NSFileProviderManager(for: $0) }

        return await makeEntity(
            for: file,
            driveFileManager: driveFileManager,
            fileProviderManager: manager
        )
    }

    static func makeEntity(
        for file: File,
        driveFileManager: DriveFileManager,
        fileProviderManager: NSFileProviderManager?
    ) async -> KDriveFileEntity {
        let userId = driveFileManager.drive.userId

        if let fileProviderManager,
           let fileProviderURL = try? await fileProviderManager.getUserVisibleURL(
               for: NSFileProviderItemIdentifier(file.id)
           ),
           let entity = try? KDriveFileEntity(
               file: file,
               userId: userId,
               fileProviderURL: fileProviderURL
           ) {
            return entity
        }

        return KDriveFileEntity(
            file: file,
            userId: userId,
            id: .draft(
                identifier: "\(userId):\(file.driveId):\(file.id)"
            )
        )
    }

    private init(file: File, userId: Int, id: FileEntityIdentifier) {
        self.id = id
        objectId = file.uid
        self.userId = userId
        driveId = file.driveId
        fileId = file.id
        name = file.name
        contentTypeIdentifier = file.typeIdentifier

        @InjectService var accountManager: AccountManageable
        let driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId)
        categoryNames = driveFileManager?.drive.categories(for: file).map { $0.localizedName } ?? []

        creationDate = file.createdAt
        fileModificationDate = file.lastModifiedAt
    }

    struct KDriveEntityQuery: EntityStringQuery {
        func entities(
            for identifiers: [KDriveFileEntity.ID]
        ) async throws -> [KDriveFileEntity] {
            @InjectService var accountManager: AccountManageable
            @InjectService var driveInfosManager: DriveInfosManager

            var entities = [KDriveFileEntity]()
            entities.reserveCapacity(identifiers.count)

            for identifier in identifiers {
                if let draftIdentifier = identifier.draftIdentifier {
                    let components = draftIdentifier.split(separator: ":")

                    if components.count == 3,
                       let userId = Int(components[0]),
                       let driveId = Int(components[1]),
                       let fileId = Int(components[2]),
                       let driveFileManager = accountManager.getDriveFileManager(
                           for: driveId,
                           userId: userId
                       ),
                       let file = driveFileManager.getCachedFile(id: fileId),
                       !file.isTrashed {
                        entities.append(KDriveFileEntity(file: file, userId: userId, id: identifier))
                        continue
                    }
                }

                guard let fileURL = try? await identifier.fileURL,
                      let providerIdentifiers = try? await Self.providerIdentifiers(for: fileURL),
                      let drive = driveInfosManager.getDrive(primaryKey: providerIdentifiers.domain.rawValue),
                      let driveFileManager = accountManager.getDriveFileManager(for: drive.id, userId: drive.userId),
                      let fileId = providerIdentifiers.item.toFileId(),
                      let file = driveFileManager.getCachedFile(id: fileId),
                      !file.isTrashed else {
                    continue
                }

                entities.append(KDriveFileEntity(file: file, userId: drive.userId, id: identifier))
            }

            return entities
        }

        func entities(
            matching string: String
        ) async throws -> [KDriveFileEntity] {
            let searchTerm = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !searchTerm.isEmpty else {
                return []
            }

            @InjectService var accountManager: AccountManageable
            @InjectService var driveInfoManager: DriveInfosManager

            var matches = [(file: File, driveFileManager: DriveFileManager)]()

            for userId in accountManager.accountIds {
                let drives = driveInfoManager.getDrives(for: userId)

                for drive in drives where !drive.inMaintenance {
                    guard let driveFileManager = accountManager.getDriveFileManager(for: drive.id, userId: userId) else {
                        continue
                    }

                    let results = driveFileManager.database.fetchResults(ofType: File.self) { files in
                        files
                            .filter("id > 0 AND name CONTAINS[cd] %@", searchTerm)
                            .sorted(by: \File.sortedName, ascending: true)
                    }

                    let files = results.lazy
                        .filter { !$0.isTrashed }
                        .prefix(KDriveFileEntity.maximumResultCount)
                        .map { $0.freeze() }

                    matches.append(contentsOf: files.map {
                        (file: $0, driveFileManager: driveFileManager)
                    })
                }
            }

            let selectedMatches = matches
                .sorted { return $0.file.sortedName < $1.file.sortedName }
                .prefix(KDriveFileEntity.maximumResultCount)

            let domains = (try? await NSFileProviderManager.domains()) ?? []

            var fileProviderManagers = [String: NSFileProviderManager]()

            for domain in domains {
                guard let manager = NSFileProviderManager(for: domain) else {
                    continue
                }

                fileProviderManagers[domain.identifier.rawValue] = manager
            }

            var entities = [KDriveFileEntity]()
            entities.reserveCapacity(selectedMatches.count)

            for match in selectedMatches {
                let driveObjectId = match.driveFileManager.drive.objectId
                let fileProviderManager = fileProviderManagers[driveObjectId]

                let entity = await makeEntity(
                    for: match.file,
                    driveFileManager: match.driveFileManager,
                    fileProviderManager: fileProviderManager
                )

                entities.append(entity)
            }

            return entities
        }

        private static func providerIdentifiers(
            for url: URL
        ) async throws -> (item: NSFileProviderItemIdentifier, domain: NSFileProviderDomainIdentifier) {
            try await withCheckedThrowingContinuation { continuation in
                NSFileProviderManager.getIdentifierForUserVisibleFile(at: url) { item, domain, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let item, let domain {
                        continuation.resume(returning: (item, domain))
                    } else {
                        continuation.resume(throwing: CocoaError(.fileNoSuchFile))
                    }
                }
            }
        }
    }
}
