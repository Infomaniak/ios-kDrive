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

import Algorithms
import CoreSpotlight
import FileProvider
import InfomaniakDI
import OSLog

public final class SpotlightIndexer {
    private static let logger = Logger(category: "SpotlightIndexer")

    public static let spotlightIndexName = "kDrive"
    public static let maxIndexedItems = 500
    public static let shared = SpotlightIndexer()

    private let operationQueue = SpotlightIndexOperationQueue()

    public init() {}

    public func indexAllItems() {
        guard #available(iOS 18.4, *) else {
            return
        }

        Task {
            await operationQueue.perform {
                @InjectService var accountManager: AccountManageable

                let date = Date()

                let searchableIndex = CSSearchableIndex(name: Self.spotlightIndexName)
                try? await searchableIndex.deleteAppEntities(ofType: KDriveFileEntity.self)

                guard let domains = try? await NSFileProviderManager.domains() else {
                    return
                }

                let drives = accountManager.drives.map { $0.freeze() }

                await drives.concurrentForEach { drive in
                    guard let driveFileManager = accountManager.getDriveFileManager(for: drive.id, userId: drive.userId),
                          let domain = domains.first(where: { $0.identifier.rawValue == drive.objectId }),
                          let fileProviderManager = NSFileProviderManager(for: domain) else {
                        return
                    }

                    let files = Array(
                        driveFileManager.database
                            .fetchResults(ofType: File.self) { $0 }
                            .sorted(by: \.lastModifiedAt, ascending: false)
                            .filter("id > 0")
                            .prefix(Self.maxIndexedItems)
                            .filter { !$0.isTrashed }
                            .map { $0.freeze() }
                    )

                    var entities = [KDriveFileEntity]()
                    entities.reserveCapacity(files.count)

                    for file in files {
                        let entity = await KDriveFileEntity.makeEntity(
                            for: file,
                            driveFileManager: driveFileManager,
                            fileProviderManager: fileProviderManager
                        )
                        entities.append(entity)
                    }

                    guard !entities.isEmpty else { return }

                    try? await searchableIndex.indexAppEntities(entities)
                }

                Self.logger.info("Spotlight updated in \(Date().timeIntervalSince(date)) seconds")
            }
        }
    }

    public func deindexItemsForDrive(userId: Int, driveId: Int) {
        guard #available(iOS 18.4, *) else {
            return
        }

        Task {
            await operationQueue.perform {
                let domainIdentifier = KDriveFileEntity.spotlightDomainIdentifier(userId: userId, driveId: driveId)
                do {
                    try await CSSearchableIndex(name: Self.spotlightIndexName).deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
                } catch {
                    Self.logger.error("Failed to remove a drive from Spotlight: \(error)")
                }
            }
        }
    }

    public func deindexAllItems() {
        guard #available(iOS 18.4, *) else {
            return
        }

        Task {
            await operationQueue.perform {
                do {
                    try await CSSearchableIndex(name: Self.spotlightIndexName).deleteAllSearchableItems()
                } catch {
                    Self.logger.error("Failed to clear the Spotlight index: \(error)")
                }
            }
        }
    }
}

private actor SpotlightIndexOperationQueue {
    private var pendingOperation: Task<Void, Never>?

    func perform(_ operation: @escaping @Sendable () async -> Void) async {
        let previousOperation = pendingOperation
        let operationTask = Task {
            await previousOperation?.value
            await operation()
        }
        pendingOperation = operationTask
        await operationTask.value
    }
}
