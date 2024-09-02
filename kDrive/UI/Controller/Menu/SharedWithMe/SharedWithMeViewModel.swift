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

import kDriveCore
import RealmSwift
import UIKit

/// Public share view model, loading content from memory realm
final class PublicShareViewModel: InMemoryFileListViewModel {
    var publicShareProxy: PublicShareProxy?
    let rootProxy: ProxyFile
    var publicShareApiFetcher: PublicShareApiFetcher?

    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        guard let currentDirectory else {
            fatalError("woops")
        }

        let configuration = Configuration(selectAllSupported: false,
                                          rootTitle: "public share",
                                          emptyViewType: .emptyFolder,
                                          supportsDrop: false,
                                          matomoViewPath: [MatomoUtils.Views.menu.displayName, "publicShare"])

        rootProxy = currentDirectory.proxify()
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        observedFiles = AnyRealmCollection(currentDirectory.children)
        print("• observedFiles :\(observedFiles.count)")
    }

    convenience init(
        publicShareProxy: PublicShareProxy,
        sortType: SortType,
        driveFileManager: DriveFileManager,
        currentDirectory: File,
        apiFetcher: PublicShareApiFetcher
    ) {
        self.init(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        self.publicShareProxy = publicShareProxy
        self.sortType = sortType
        publicShareApiFetcher = apiFetcher
    }

    override func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        print("• loadFiles:\(cursor):\(forceRefresh)")
        guard !isLoading || cursor != nil,
              let publicShareProxy,
              let publicShareApiFetcher else {
            return
        }

        // Only show loading indicator if we have nothing in cache
        if !currentDirectory.canLoadChildrenFromCache {
            startRefreshing(cursor: cursor)
        }
        defer {
            endRefreshing()
        }

        let (_, nextCursor) = try await driveFileManager.publicShareFiles(rootProxy: rootProxy,
                                                                          publicShareProxy: publicShareProxy,
                                                                          publicShareApiFetcher: publicShareApiFetcher)
        print("• nextCursor:\(nextCursor)")
        endRefreshing()
        if let nextCursor {
            try await loadFiles(cursor: nextCursor)
        }
    }
}

class SharedWithMeViewModel: FileListViewModel {
    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        let sharedWithMeRootFile = driveFileManager.getManagedFile(from: DriveFileManager.sharedWithMeRootFile)
        let configuration = Configuration(selectAllSupported: false,
                                          rootTitle: KDriveCoreStrings.Localizable.sharedWithMeTitle,
                                          emptyViewType: .noSharedWithMe,
                                          supportsDrop: false,
                                          matomoViewPath: [MatomoUtils.Views.menu.displayName, "SharedWithMe"])

        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: sharedWithMeRootFile)
        observedFiles = AnyRealmCollection(AnyRealmCollection(sharedWithMeRootFile.children).filesSorted(by: sortType))
    }

    override func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        guard !isLoading || cursor != nil else { return }

        // Only show loading indicator if we have nothing in cache
        if !currentDirectory.canLoadChildrenFromCache {
            startRefreshing(cursor: cursor)
        }
        defer {
            endRefreshing()
        }

        let (_, nextCursor) = try await driveFileManager.sharedWithMeFiles(cursor: cursor, sortType: sortType, forceRefresh: true)
        endRefreshing()
        if let nextCursor {
            try await loadFiles(cursor: nextCursor)
        }
    }
}
