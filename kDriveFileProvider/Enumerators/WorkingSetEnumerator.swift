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

import FileProvider
import Foundation
import kDriveCore

final class WorkingSetEnumerator: NSObject, NSFileProviderEnumerator {
    private let requests: AsyncStream<NSFileProviderEnumerationObserver>.Continuation
    let enumerationTask: Task<Void, Never>

    convenience init(driveFileManager: DriveFileManager, domain: NSFileProviderDomain?) {
        self.init {
            // Keep live Realm objects within this synchronous scope, with no suspension points.
            autoreleasepool {
                let files = driveFileManager.getWorkingSet()
                let drive = driveFileManager.drive
                var items = [NSFileProviderItem]()
                for file in files {
                    guard !Task.isCancelled else { return [] }
                    autoreleasepool {
                        items.append(file.toFileProviderItem(parent: .workingSet, drive: drive, domain: domain))
                    }
                }
                return items
            }
        }
    }

    init(loadItems: @escaping () async -> [NSFileProviderItem]) {
        var continuation: AsyncStream<NSFileProviderEnumerationObserver>.Continuation!
        let stream = AsyncStream<NSFileProviderEnumerationObserver> { continuation = $0 }
        requests = continuation
        // One consumer preserves request order without sharing mutable task state.
        enumerationTask = Task {
            await Self.processRequests(stream, loadItems: loadItems)
        }
    }

    @concurrent
    private static func processRequests(
        _ stream: AsyncStream<NSFileProviderEnumerationObserver>,
        loadItems: () async -> [NSFileProviderItem]
    ) async {
        for await observer in stream {
            guard !Task.isCancelled else { return }
            let items = await loadItems()
            guard !Task.isCancelled else { return }
            observer.didEnumerate(items)
            guard !Task.isCancelled else { return }
            observer.finishEnumerating(upTo: nil)
        }
    }

    deinit {
        enumerationTask.cancel()
        requests.finish()
    }

    func invalidate() {
        enumerationTask.cancel()
        requests.finish()
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        requests.yield(observer)
    }
}
