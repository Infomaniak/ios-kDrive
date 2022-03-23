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
import kDriveCore

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    private let containerItemIdentifier: NSFileProviderItemIdentifier
    private let isDirectory: Bool
    private let domain: NSFileProviderDomain?
    private let driveFileManager: DriveFileManager
    private static let syncAnchorExpireTime = TimeInterval(60 * 60 * 24 * 7) // One week

    init(containerItem: NSFileProviderItem, driveFileManager: DriveFileManager, domain: NSFileProviderDomain?) {
        self.containerItemIdentifier = containerItem.itemIdentifier
        self.isDirectory = containerItem.childItemCount != nil
        self.domain = domain
        self.driveFileManager = driveFileManager
    }

    init(containerItemIdentifier: NSFileProviderItemIdentifier, driveFileManager: DriveFileManager, domain: NSFileProviderDomain?) {
        self.containerItemIdentifier = containerItemIdentifier
        self.isDirectory = false
        self.domain = domain
        self.driveFileManager = driveFileManager
    }

    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        if containerItemIdentifier == .workingSet {
            let workingSetFiles = driveFileManager.getWorkingSet()
            var containerItems = [FileProviderItem]()
            for file in workingSetFiles {
                autoreleasepool {
                    containerItems.append(FileProviderItem(file: file, domain: domain))
                }
            }
            containerItems += FileProviderExtensionState.shared.workingSet.values
            observer.didEnumerate(containerItems)
            observer.finishEnumerating(upTo: nil)
        } else {
            guard let fileId = containerItemIdentifier.toFileId() else {
                observer.finishEnumeratingWithError(nsError(code: .noSuchItem))
                return
            }
            let pageIndex = page.isInitialPage ? 1 : page.toInt

            var forceRefresh = false
            if let lastResponseAt = driveFileManager.getCachedFile(id: fileId)?.responseAt {
                let anchorExpireTimestamp = Int(Date(timeIntervalSinceNow: -FileProviderEnumerator.syncAnchorExpireTime).timeIntervalSince1970)
                forceRefresh = lastResponseAt < anchorExpireTimestamp
            }

            Task { [forceRefresh] in
                do {
                    let file = try await driveFileManager.file(id: fileId, forceRefresh: forceRefresh)
                    let (children, moreComing) = try await driveFileManager.files(in: file, page: pageIndex, forceRefresh: forceRefresh)
                    // No need to freeze $0 it should already be frozen
                    var containerItems = [FileProviderItem]()
                    for child in children {
                        autoreleasepool {
                            containerItems.append(FileProviderItem(file: child, domain: self.domain))
                        }
                    }
                    containerItems += FileProviderExtensionState.shared.unenumeratedImportedDocuments(forParent: self.containerItemIdentifier)
                    containerItems.append(FileProviderItem(file: file, domain: self.domain))
                    observer.didEnumerate(containerItems)

                    if self.isDirectory && moreComing {
                        observer.finishEnumerating(upTo: NSFileProviderPage(pageIndex + 1))
                    } else {
                        observer.finishEnumerating(upTo: nil)
                    }
                } catch {
                    // Maybe this is a trashed file
                    do {
                        let file = try await driveFileManager.apiFetcher.trashedFile(ProxyFile(driveId: self.driveFileManager.drive.id, id: fileId))
                        let children = try await driveFileManager.apiFetcher.trashedFiles(of: file.proxify(), page: pageIndex)
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
                        if self.isDirectory && children.count == Endpoint.itemsPerPage {
                            observer.finishEnumerating(upTo: NSFileProviderPage(pageIndex + 1))
                        } else {
                            observer.finishEnumerating(upTo: nil)
                        }
                    } catch {
                        if let error = error as? DriveError, error == .maintenance {
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
        if let directoryIdentifier = containerItemIdentifier.toFileId() {
            let lastTimestamp = anchor.toInt
            let anchorExpireTimestamp = Int(Date(timeIntervalSinceNow: -FileProviderEnumerator.syncAnchorExpireTime).timeIntervalSince1970)
            if lastTimestamp < anchorExpireTimestamp {
                observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
                return
            }

            Task {
                do {
                    let file = try await driveFileManager.file(id: directoryIdentifier)
                    let (results, timestamp) = try await driveFileManager.fileActivities(file: file.proxify(), from: lastTimestamp)
                    let updated = results.inserted + results.updated
                    var updatedItems = [NSFileProviderItem]()
                    for updatedChild in updated {
                        autoreleasepool {
                            updatedItems.append(FileProviderItem(file: updatedChild, domain: self.domain))
                        }
                    }
                    updatedItems += FileProviderExtensionState.shared.unenumeratedImportedDocuments(forParent: self.containerItemIdentifier)
                    observer.didUpdate(updatedItems)

                    var deletedItems = results.deleted.map { NSFileProviderItemIdentifier("\($0.id)") }
                    deletedItems += FileProviderExtensionState.shared.deleteAlreadyEnumeratedImportedDocuments(forParent: self.containerItemIdentifier)
                    observer.didDeleteItems(withIdentifiers: deletedItems)

                    observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(timestamp), moreComing: false)
                } catch {
                    // Maybe this is a trashed file
                    do {
                        let file = try await driveFileManager.apiFetcher.trashedFile(ProxyFile(driveId: driveFileManager.drive.id, id: directoryIdentifier))
                        observer.didUpdate([FileProviderItem(file: file, domain: self.domain)])
                        observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(file.responseAt), moreComing: false)
                    } catch {
                        if let error = error as? DriveError, error == .maintenance {
                            observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                        } else {
                            // File not found
                            observer.finishEnumeratingWithError(NSFileProviderError(.noSuchItem))
                        }
                    }
                }
            }
        } else {
            // Update working set
            observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
        }
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        if let fileId = containerItemIdentifier.toFileId() {
            if let file = driveFileManager.getCachedFile(id: fileId) {
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

extension NSFileProviderPage {
    init(_ integer: Int) {
        self.init(withUnsafeBytes(of: integer.littleEndian) { Data($0) })
    }

    var toInt: Int {
        return rawValue.withUnsafeBytes { $0.load(as: Int.self) }.littleEndian
    }

    var isInitialPage: Bool {
        return self == NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage || self == NSFileProviderPage.initialPageSortedByName as NSFileProviderPage
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
