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

import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import OSLog
import RealmSwift
import UIKit

class OfflineFilesViewModel: FileListViewModel {
    private let sharedWithMeDriveFileManager: DriveFileManager
    private var sharedResults: AnyRealmCollection<File>?
    private var sharedRealmObservationToken: NotificationToken?
    private var driveFiles: [File] = []
    private var sharedFiles: [File] = []

    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        sharedWithMeDriveFileManager = driveFileManager.instanceWith(context: .sharedWithMe)
        let configuration = Configuration(normalFolderHierarchy: false,
                                          showUploadingFiles: false,
                                          isRefreshControlEnabled: true,
                                          selectAllSupported: true,
                                          rootTitle: KDriveResourcesStrings.Localizable.offlineFileTitle,
                                          emptyViewType: .noOffline,
                                          matomoViewPath: [MatomoUtils.View.menu.displayName, "Offline"])
        // We don't really need a current directory for offline files
        super.init(
            configuration: configuration,
            driveFileManager: driveFileManager,
            currentDirectory: DriveFileManager.offlineRoot
        )

        let results = driveFileManager.database.fetchResults(ofType: File.self) { lazyCollection in
            lazyCollection.filter("isAvailableOffline = true")
        }
        observedFiles = AnyRealmCollection(results)

        let sharedResults = sharedWithMeDriveFileManager.database.fetchResults(ofType: File.self) { lazyCollection in
            lazyCollection.filter("isAvailableOffline = true")
        }
        self.sharedResults = AnyRealmCollection(sharedResults)
    }

    override func forceRefresh() {
        @LazyInjectService var offlineManager: AvailableOfflineManageable
        offlineManager.updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)
        endRefreshing()
    }

    override func shouldShowEmptyView() -> Bool {
        files.isEmpty
    }

    override func sortingChanged() {
        observedFiles = AnyRealmCollection(observedFiles.filesSorted(by: sortType))
        if let sharedResults {
            self.sharedResults = AnyRealmCollection(sharedResults.filesSorted(by: sortType))
        }
        updateRealmObservation()
    }

    override func updateRealmObservation() {
        realmObservationToken?.invalidate()
        realmObservationToken = observedFiles
            .observe(keyPaths: FileViewModel.observedProperties, on: .main) { [weak self] change in
                self?.handleCollectionChange(change, isShared: false)
            }

        sharedRealmObservationToken?.invalidate()
        guard let sharedResults else { return }
        sharedRealmObservationToken = sharedResults
            .observe(keyPaths: FileViewModel.observedProperties, on: .main) { [weak self] change in
                self?.handleCollectionChange(change, isShared: true)
            }
    }

    private func handleCollectionChange(_ change: RealmCollectionChange<AnyRealmCollection<File>>, isShared: Bool) {
        let newFiles: [File]
        switch change {
        case .initial(let results), .update(let results, _, _, _):
            newFiles = Array(results.freezeIfNeeded())
        case .error(let error):
            Logger.realmObservation.error("Error \(error)")
            return
        }
        if isShared {
            sharedFiles = newFiles
        } else {
            driveFiles = newFiles
        }
        refreshMergedFiles()
    }

    private func refreshMergedFiles() {
        var seen = Set<String>()
        let merged = (driveFiles + sharedFiles).filter { seen.insert($0.uid).inserted }
        files = merged.sorted { lhs, rhs in
            if lhs.type?.rawValue != rhs.type?.rawValue {
                return lhs.type?.rawValue ?? "" < rhs.type?.rawValue ?? ""
            }
            if lhs.visibility?.rawValue != rhs.visibility?.rawValue {
                return lhs.visibility?.rawValue ?? "" > rhs.visibility?.rawValue ?? ""
            }
            return sortType.compare(lhs, rhs)
        }

        let fileTypeCounts = files.reduce(into: (files: 0, directories: 0)) { counts, file in
            if file.isDirectory {
                counts.directories += 1
            } else {
                counts.files += 1
            }
        }
        directoryFilesCount = FileCount(
            count: files.count,
            files: fileTypeCounts.files,
            directories: fileTypeCounts.directories
        )
        isShowingEmptyView = shouldShowEmptyView()
    }

    override func barButtonPressed(sender: Any? = nil, type: FileListBarButtonType) {
        let viewModel = multipleSelectionViewModel
        viewModel?.isSelectAllModeEnabled = true
        viewModel?.forceMoveDistinctFiles = true
        viewModel?.rightBarButtons = [.loading]
        viewModel?.onSelectAll?()
        if type == .selectAll {
            let frozenFiles = driveFileManager.database.fetchResults(ofType: File.self) { lazyCollection in
                lazyCollection.filter("isAvailableOffline = true")
            }.freeze()
            let sharedFrozenFiles = sharedWithMeDriveFileManager.database.fetchResults(ofType: File.self) { lazyCollection in
                lazyCollection.filter("isAvailableOffline = true")
            }.freeze()
            viewModel?.didSelectFiles(Set(Array(frozenFiles) + Array(sharedFrozenFiles)))
            viewModel?.rightBarButtons = [.deselectAll]
        } else {
            super.barButtonPressed(sender: sender, type: type)
        }
    }
}

private extension SortType {
    func compare(_ lhs: File, _ rhs: File) -> Bool {
        switch self {
        case .nameAZ, .ext, .relevance, .type, .olderDelete, .newerDelete:
            return lhs.sortedName < rhs.sortedName
        case .nameZA:
            return lhs.sortedName > rhs.sortedName
        case .older:
            return lhs.lastModifiedAt < rhs.lastModifiedAt
        case .newer:
            return lhs.lastModifiedAt > rhs.lastModifiedAt
        case .biggest:
            return (lhs.size ?? 0) > (rhs.size ?? 0)
        case .smallest:
            return (lhs.size ?? 0) < (rhs.size ?? 0)
        }
    }
}
