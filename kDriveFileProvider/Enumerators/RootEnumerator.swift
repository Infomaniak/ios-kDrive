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
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import RealmSwift

class RootEnumerator: NSObject, NSFileProviderEnumerator {
    private let driveFileManager: DriveFileManager
    private let domain: NSFileProviderDomain?

    let containerItemIdentifier = NSFileProviderItemIdentifier.rootContainer

    init(driveFileManager: DriveFileManager, domain: NSFileProviderDomain?) {
        self.driveFileManager = driveFileManager
        self.domain = domain
    }

    func invalidate() {}

    func fetchRoot(page: NSFileProviderPage) async throws -> (files: [File], nextCursor: String?) {
        let parentDirectory = try driveFileManager.getCachedFile(itemIdentifier: containerItemIdentifier)

        guard !parentDirectory.fullyDownloaded else {
            return (Array(parentDirectory.children) + [parentDirectory], nil)
        }

        let currentPageCursor = page.isInitialPage ? nil : page.toCursor
        let response = try await driveFileManager.apiFetcher.rootFiles(
            drive: driveFileManager.drive,
            cursor: currentPageCursor
        ).validApiResponse
        let files = response.data

        var liveParent: File?
        try driveFileManager.database.writeTransaction { writableRealm in
            let liveParentDirectory = try driveFileManager.getCachedFile(
                itemIdentifier: containerItemIdentifier,
                freeze: false,
                using: writableRealm
            )
            liveParent = liveParentDirectory

            try driveFileManager.writeChildrenToParent(
                files,
                liveParent: liveParentDirectory,
                responseAt: response.responseAt,
                isInitialCursor: page.isInitialPage,
                writableRealm: writableRealm
            )

            try updateAnchor(for: liveParentDirectory, from: response, writableRealm: writableRealm)
        }

        let nextCursor = response.hasMore ? response.cursor : nil
        guard let liveParent else {
            return (files, nextCursor)
        }

        return (files + [liveParent.freezeIfNeeded()], nextCursor)
    }

    /// Update anchor for parent
    /// - Parameters:
    ///   - parent: Parent file
    ///   - response: API response
    ///   - writableRealm: A realm __within__ a save transaction
    func updateAnchor(for parent: File, from response: ValidApiResponse<[File]>, writableRealm: Realm) throws {
        parent.responseAt = response.responseAt ?? Int(Date().timeIntervalSince1970)
        parent.lastCursor = response.cursor
        parent.fullyDownloaded = response.hasMore
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Task {
            do {
                let (files, nextCursor) = try await self.fetchRoot(page: page)
                observer.didEnumerate(files.map { $0.toFileProviderItem(parent: .rootContainer, domain: domain) })

                // there should never be more cursors but still implement next page logic just in case
                if let nextCursor {
                    observer.finishEnumerating(upTo: NSFileProviderPage(nextCursor))
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
            } catch let error as NSFileProviderError {
                observer.finishEnumeratingWithError(error)
            } catch {
                Log.fileProvider("RootEnumerator - Error in enumerateItems \(error)", level: .error)
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
            }
        }
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        guard let cursor = syncAnchor.toCursor else {
            observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
            return
        }

        Task {
            do {
                let response = try await driveFileManager.apiFetcher.rootFiles(
                    drive: driveFileManager.drive,
                    cursor: cursor
                ).validApiResponse

                guard let syncAnchor = NSFileProviderSyncAnchor(response.cursor) else {
                    observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
                    return
                }

                var childIdsBeforeUpdate = Set<Int>()
                var liveParentDirectory: File?
                try self.driveFileManager.database.writeTransaction { writableRealm in
                    guard let fetchedParentDirectory = try? self.driveFileManager.getCachedFile(
                        itemIdentifier: self.containerItemIdentifier,
                        freeze: false,
                        using: writableRealm
                    ) else {
                        return
                    }

                    liveParentDirectory = fetchedParentDirectory

                    childIdsBeforeUpdate = Set(fetchedParentDirectory.children.map { $0.id })
                    try driveFileManager.writeChildrenToParent(
                        response.data,
                        liveParent: fetchedParentDirectory,
                        responseAt: response.responseAt,
                        isInitialCursor: false,
                        writableRealm: writableRealm
                    )
                }

                guard let liveParentDirectory else {
                    throw NSFileProviderError(.noSuchItem)
                }

                // Notify after transaction
                let childIdsAfterUpdate = Set(liveParentDirectory.children.map { $0.id })

                // Manual diffing since we don't have activities for root
                let deletedIds = childIdsAfterUpdate.subtracting(childIdsBeforeUpdate)

                let updatedFiles = liveParentDirectory.children + [liveParentDirectory]
                observer.didUpdate(updatedFiles.map { $0.toFileProviderItem(parent: .rootContainer, domain: domain) })
                observer.didDeleteItems(withIdentifiers: deletedIds.map { NSFileProviderItemIdentifier($0) })
                observer.finishEnumeratingChanges(
                    upTo: syncAnchor,
                    moreComing: response.hasMore
                )

            } catch let error as NSFileProviderError {
                observer.finishEnumeratingWithError(error)
            } catch {
                Log.fileProvider("RootEnumerator - Error in enumerateChanges \(error)", level: .error)
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
            }
        }
    }

    func currentSyncAnchor() async -> NSFileProviderSyncAnchor? {
        guard let parentDirectory = try? driveFileManager.getCachedFile(itemIdentifier: containerItemIdentifier),
              parentDirectory.fullyDownloaded,
              let currentSyncAnchor = NSFileProviderSyncAnchor(parentDirectory.lastCursor) else {
            return nil
        }

        return currentSyncAnchor
    }
}
