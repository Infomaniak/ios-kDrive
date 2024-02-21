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

final class RootEnumerator: NSObject, NSFileProviderEnumerator {
    private let driveFileManager: DriveFileManager
    private let domain: NSFileProviderDomain?

    let containerItemIdentifier = NSFileProviderItemIdentifier.rootContainer

    init(driveFileManager: DriveFileManager, domain: NSFileProviderDomain?) {
        self.driveFileManager = driveFileManager
        self.domain = domain
    }

    // MARK: - NSFileProviderEnumerator

    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Task { [weak self] in
            guard let self else {
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                return
            }

            do {
                let (files, nextCursor) = try await fetchRoot(page: page)
                observer.didEnumerate(files.map { FileProviderItem(file: $0, parent: .rootContainer, domain: domain) })

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

        Task { [weak self] in
            guard let self else {
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                return
            }

            do {
                let (files, response) = try await driveFileManager.apiFetcher.rootFiles(
                    drive: driveFileManager.drive,
                    cursor: cursor
                )

                let realm = driveFileManager.getRealm()
                guard let liveParentDirectory = try? driveFileManager.getCachedFile(
                    itemIdentifier: containerItemIdentifier,
                    freeze: false,
                    using: realm
                ) else {
                    observer.finishEnumeratingWithError(NSFileProviderError(.noSuchItem))
                    return
                }

                guard let syncAnchor = NSFileProviderSyncAnchor(response.cursor) else {
                    observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
                    return
                }

                let childIdsBeforeUpdate = Set(liveParentDirectory.children.map { $0.id })
                try driveFileManager.writeChildrenToParent(
                    files,
                    liveParent: liveParentDirectory,
                    responseAt: response.responseAt,
                    isInitialCursor: false,
                    using: realm
                )

                let childIdsAfterUpdate = Set(liveParentDirectory.children.map { $0.id })

                // Manual diffing since we don't have activities for root
                let deletedIds = childIdsAfterUpdate.subtracting(childIdsBeforeUpdate)

                let updatedFiles = liveParentDirectory.children + [liveParentDirectory]
                observer.didUpdate(updatedFiles.map { FileProviderItem(file: $0, parent: .rootContainer, domain: domain) })
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

    // MARK: - Private

    private func fetchRoot(page: NSFileProviderPage) async throws -> (files: [File], nextCursor: String?) {
        let parentDirectory = try driveFileManager.getCachedFile(itemIdentifier: containerItemIdentifier)

        guard !parentDirectory.fullyDownloaded else {
            return (Array(parentDirectory.children) + [parentDirectory], nil)
        }

        let currentPageCursor = page.isInitialPage ? nil : page.toCursor
        let (files, response) = try await driveFileManager.apiFetcher.rootFiles(
            drive: driveFileManager.drive,
            cursor: currentPageCursor
        )

        let realm = driveFileManager.getRealm()
        let liveParentDirectory = try driveFileManager.getCachedFile(
            itemIdentifier: containerItemIdentifier,
            freeze: false,
            using: realm
        )

        try driveFileManager.writeChildrenToParent(
            files,
            liveParent: liveParentDirectory,
            responseAt: response.responseAt,
            isInitialCursor: page.isInitialPage,
            using: realm
        )

        try updateAnchor(for: liveParentDirectory, from: response, using: realm)

        return (files + [liveParentDirectory.freezeIfNeeded()], response.hasMore ? response.cursor : nil)
    }

    private func updateAnchor(for parent: File, from response: ApiResponse<[File]>, using realm: Realm) throws {
        try realm.write {
            parent.responseAt = response.responseAt ?? Int(Date().timeIntervalSince1970)
            parent.lastCursor = response.cursor
            parent.fullyDownloaded = response.hasMore
        }
    }
}
