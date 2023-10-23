/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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

import FileProvider
import InfomaniakCore
import InfomaniakDI
import kDriveCore

final class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    private let containerItemIdentifier: NSFileProviderItemIdentifier
    private let isDirectory: Bool
    private let domain: NSFileProviderDomain?
    private let driveFileManager: DriveFileManager
    private static let syncAnchorExpireTime = TimeInterval(60 * 60 * 24 * 7) // One week

    @LazyInjectService var fileProviderState: FileProviderExtensionAdditionalStatable

    /// Something to enqueue async await tasks in a serial manner.
    let asyncAwaitQueue = TaskQueue()

    /// Enqueue an async/await closure in the underlaying serial execution queue.
    /// - Parameter task: A closure with async await code to be dispatched
    private func enqueue(_ task: @escaping () async throws -> Void) {
        Task {
            try await asyncAwaitQueue.enqueue(asap: false) {
                try await task()
            }
        }
    }

    init(containerItem: NSFileProviderItem, driveFileManager: DriveFileManager, domain: NSFileProviderDomain?) {
        containerItemIdentifier = containerItem.itemIdentifier
        isDirectory = containerItem.childItemCount != nil
        self.domain = domain
        self.driveFileManager = driveFileManager
    }

    init(
        containerItemIdentifier: NSFileProviderItemIdentifier,
        driveFileManager: DriveFileManager,
        domain: NSFileProviderDomain?
    ) {
        self.containerItemIdentifier = containerItemIdentifier
        isDirectory = false
        self.domain = domain
        self.driveFileManager = driveFileManager
    }

    func invalidate() {
        Log.fileProvider("invalidate")
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Log.fileProvider("enumerateItems for observer")
        enqueue {
            // Recent files folder
            if self.containerItemIdentifier == .workingSet {
                let workingSetFiles = self.driveFileManager.getWorkingSet()
                var containerItems = [FileProviderItem]()
                for file in workingSetFiles {
                    autoreleasepool {
                        containerItems.append(FileProviderItem(file: file, domain: self.domain))
                    }
                }
                containerItems += self.fileProviderState.getWorkingDocumentValues()
                observer.didEnumerate(containerItems)
                observer.finishEnumerating(upTo: nil)
            }
            // Any other folder
            else {
                guard let fileId = self.containerItemIdentifier.toFileId() else {
                    observer.finishEnumeratingWithError(self.nsError(code: .noSuchItem))
                    return
                }
                let cursor = page.isInitialPage ? nil : page.toCursor

                var forceRefresh = false
                if let lastResponseAt = self.driveFileManager.getCachedFile(id: fileId)?.responseAt {
                    let anchorExpireTimestamp = Int(Date(timeIntervalSinceNow: -FileProviderEnumerator.syncAnchorExpireTime)
                        .timeIntervalSince1970)
                    forceRefresh = lastResponseAt < anchorExpireTimestamp
                }

                do {
                    let file = try await self.driveFileManager.file(id: fileId, forceRefresh: forceRefresh)
                    let (children, moreComing) = try await self.driveFileManager
                        .files(in: file.proxify(), cursor: cursor, forceRefresh: forceRefresh)
                    // No need to freeze $0 it should already be frozen
                    var containerItems = [FileProviderItem]()
                    for child in children {
                        autoreleasepool {
                            containerItems.append(FileProviderItem(file: child, domain: self.domain))
                        }
                    }

                    containerItems.append(FileProviderItem(file: file, domain: self.domain))
                    observer.didEnumerate(containerItems)

                    if self.isDirectory, let cursor {
                        observer.finishEnumerating(upTo: NSFileProviderPage(cursor))
                    } else {
                        observer.finishEnumerating(upTo: nil)
                    }
                } catch {
                    // Maybe this is a trashed file
                    do {
                        let file = try await self.driveFileManager.apiFetcher
                            .trashedFile(ProxyFile(driveId: self.driveFileManager.drive.id, id: fileId))
                        let children = try await self.driveFileManager.apiFetcher.trashedFiles(
                            of: file.proxify(),
                            cursor: cursor
                        )
                        var containerItems = [FileProviderItem]()
                        for child in children {
                            autoreleasepool {
                                let item = FileProviderItem(file: child, domain: self.domain)
                                item.parentItemIdentifier = self.containerItemIdentifier
                                containerItems.append(item)
                            }
                        }
                        containerItems.append(FileProviderItem(file: file, domain: self.domain))
                        observer.didEnumerate(containerItems)
                        // FIXME: Cursors also for trash
                        /* if self.isDirectory && children.count == Endpoint.itemsPerPage {
                             observer.finishEnumerating(upTo: NSFileProviderPage(pageIndex + 1))
                         } else {
                             observer.finishEnumerating(upTo: nil)
                         } */
                    } catch {
                        if let error = error as? DriveError, error == .productMaintenance {
                            observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                        } else {
                            // File not found
                            observer.finishEnumeratingWithError(NSFileProviderError(.noSuchItem))
                        }
                    }
                }
            }
        }
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        Log.fileProvider("enumerateChanges for observer")
        enqueue {
            if let directoryIdentifier = self.containerItemIdentifier.toFileId() {
                let lastTimestamp = anchor.toInt
                let anchorExpireTimestamp = Int(Date(timeIntervalSinceNow: -FileProviderEnumerator.syncAnchorExpireTime)
                    .timeIntervalSince1970)
                if lastTimestamp < anchorExpireTimestamp {
                    observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
                    return
                }

                do {
                    let file = try await self.driveFileManager.file(id: directoryIdentifier)
                    let (results, timestamp) = try await self.driveFileManager
                        .fileActivities(file: file.proxify(), from: lastTimestamp)
                    let updated = results.inserted + results.updated
                    var updatedItems = [NSFileProviderItem]()
                    for updatedChild in updated {
                        autoreleasepool {
                            updatedItems.append(FileProviderItem(file: updatedChild, domain: self.domain))
                        }
                    }

                    observer.didUpdate(updatedItems)

                    // We remove placeholder files only on upload success / failure.
                    // We do not change anything during an enumeration
                    var deletedItems = results.deleted.map { NSFileProviderItemIdentifier("\($0.id)") }
                    deletedItems += self.fileProviderState
                        .deleteAlreadyEnumeratedImportedDocuments(forParent: self.containerItemIdentifier)
                    observer.didDeleteItems(withIdentifiers: deletedItems)

                    observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(timestamp), moreComing: false)
                } catch {
                    // Maybe this is a trashed file
                    do {
                        let file = try await self.driveFileManager.apiFetcher
                            .trashedFile(ProxyFile(driveId: self.driveFileManager.drive.id, id: directoryIdentifier))
                        observer.didUpdate([FileProviderItem(file: file, domain: self.domain)])
                        observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(file.responseAt), moreComing: false)
                    } catch {
                        if let error = error as? DriveError, error == .productMaintenance {
                            observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                        } else {
                            // File not found
                            observer.finishEnumeratingWithError(NSFileProviderError(.noSuchItem))
                        }
                    }
                }
            } else {
                // Update working set
                observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
            }
        }
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        Log.fileProvider("currentSyncAnchor completionHandler")
        enqueue {
            if let fileId = self.containerItemIdentifier.toFileId() {
                if let file = self.driveFileManager.getCachedFile(id: fileId) {
                    if file.isDirectory {
                        let anchor = NSFileProviderSyncAnchor(file.responseAt)
                        completionHandler(anchor)
                    } else {
                        // We don't support changes enumeration for a single file
                        completionHandler(nil)
                    }
                } else {
                    // Maybe this is a trashed file
                    completionHandler(nil)
                }
            } else {
                // Working set doesn't support enumerating changes yet
                completionHandler(nil)
            }
        }
    }
}

extension NSFileProviderPage {
    init(_ cursor: String) {
        self.init(cursor.data(using: .utf8) ?? Data())
    }

    var toCursor: String? {
        return String(data: rawValue, encoding: .utf8)
    }

    var isInitialPage: Bool {
        return self == NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage || self == NSFileProviderPage
            .initialPageSortedByName as NSFileProviderPage
    }
}

extension NSFileProviderSyncAnchor {
    init(_ integer: Int) {
        self.init(withUnsafeBytes(of: integer.littleEndian) { Data($0) })
    }

    var toInt: Int {
        return rawValue.withUnsafeBytes { $0.load(as: Int.self) }.littleEndian
    }
}

extension FileProviderEnumerator {
    // Create an NSError based on the file provider error code.
    //
    func nsError(domain: String = NSFileProviderErrorDomain,
                 code: NSFileProviderError.Code,
                 userInfo dict: [String: Any]? = nil) -> NSError {
        return NSError(domain: NSFileProviderErrorDomain, code: code.rawValue, userInfo: dict)
    }
}
