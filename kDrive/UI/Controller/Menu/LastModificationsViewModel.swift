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
import kDriveResources
import RealmSwift
import UIKit

class LastModificationsViewModel: FileListViewModel {
    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        let configuration = Configuration(normalFolderHierarchy: false,
                                          selectAllSupported: false,
                                          rootTitle: KDriveResourcesStrings.Localizable.lastEditsTitle,
                                          emptyViewType: .noActivitiesSolo,
                                          sortingOptions: [],
                                          matomoViewPath: [MatomoUtils.Views.menu.displayName, "LastModifications"])
        super.init(
            configuration: configuration,
            driveFileManager: driveFileManager,
            currentDirectory: DriveFileManager.lastModificationsRootFile
        )

        let fetchedFiles = driveFileManager.database.fetchResults(ofType: File.self) { faultedCollection in
            faultedCollection.filter("rawType != \"dir\"")
        }

        files = AnyRealmCollection(fetchedFiles)
    }

    override func startObservation() {
        super.startObservation()
        sortTypeObservation?.cancel()
        sortTypeObservation = nil
        sortType = .newer
        sortingChanged()
    }

    override func sortingChanged() {
        files = AnyRealmCollection(files.sorted(by: [sortType.value.sortDescriptor]))
    }

    override func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        guard !isLoading || cursor != nil else { return }

        startRefreshing(cursor: cursor)
        defer {
            endRefreshing()
        }

        let (_, nextCursor) = try await driveFileManager.lastModifiedFiles(cursor: cursor)
        endRefreshing()
        if let nextCursor {
            try await loadFiles(cursor: nextCursor)
        }
    }

    override func loadActivities() async throws {
        try await loadFiles(cursor: nil, forceRefresh: true)
    }
}
