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
import InfomaniakDI
import kDriveCore

final class DirectoryEnumerator: NSObject, NSFileProviderEnumerator {
    @LazyInjectService private var fileProviderManager: FileProviderManager

    let containerItemIdentifier: NSFileProviderItemIdentifier

    init(containerItemIdentifier: NSFileProviderItemIdentifier) {
        self.containerItemIdentifier = containerItemIdentifier
        super.init()
    }

    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Task { [weak self] in
            guard let self else {
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                return
            }

            let parentDirectory = try fileProviderManager.getFile(for: containerItemIdentifier)

            guard !parentDirectory.fullyDownloaded else {
                let files = Array(parentDirectory.children) + [parentDirectory]
                observer.didEnumerate(files.map { FileProviderItem(file: $0, domain: fileProviderManager.domain) })
                observer.finishEnumerating(upTo: nil)
                return
            }

            do {
                let currentPageCursor = page.isInitialPage ? nil : page.toCursor
                let (listingResult, response) = try await fileProviderManager.driveApiFetcher.files(
                    in: parentDirectory.proxify(),
                    advancedListingCursor: currentPageCursor,
                    sortType: .nameAZ
                )

                let realm = fileProviderManager.getRealm()
                let liveParentDirectory = try fileProviderManager.getFile(
                    for: containerItemIdentifier,
                    using: realm,
                    shouldFreeze: false
                )

                var updatedFiles = try fileProviderManager.writeChildrenToParent(
                    liveParentDirectory,
                    children: listingResult.files,
                    shouldClearChildren: page.isInitialPage,
                    using: realm
                )

                try realm.write {
                    if let nextCursor = response.cursor {
                        // Last page can contain BOTH files and actions and cannot be handled this way on file provider.
                        // So we process the files and save the previous cursor to get the actions in the enumerate changes
                        if !listingResult.actions.isEmpty {
                            liveParentDirectory.lastCursor = currentPageCursor
                        } else {
                            liveParentDirectory.lastCursor = nextCursor
                        }
                        liveParentDirectory.fullyDownloaded = !response.hasMore
                    }
                }

                updatedFiles.append(liveParentDirectory)

                observer.didEnumerate(updatedFiles.map { FileProviderItem(file: $0, domain: fileProviderManager.domain) })

                if response.hasMore,
                   let nextCursor = response.cursor {
                    observer.finishEnumerating(upTo: NSFileProviderPage(nextCursor))
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
            } catch {
                // Maybe this is a trashed file
                print("Error while enumerating \(error)")
                // await enumerateItemsInTrash(for: observer, startingAt: page)
            }
        }
    }

    /* func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
         observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
     }

     func currentSyncAnchor() async -> NSFileProviderSyncAnchor? {
         return nil
     } */
}
