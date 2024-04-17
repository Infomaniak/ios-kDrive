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

import CocoaLumberjackSwift
import DifferenceKit
import Foundation
import kDriveCore
import kDriveResources
import RealmSwift

class PhotoListViewModel: FileListViewModel {
    typealias Section = ArraySection<Group, File>

    struct Group: Differentiable {
        let referenceDate: Date
        let dateComponents: DateComponents
        let sortMode: PhotoSortMode

        var differenceIdentifier: Date {
            return referenceDate
        }

        var formattedDate: String {
            return sortMode.dateFormatter.string(from: referenceDate)
        }

        init(referenceDate: Date, sortMode: PhotoSortMode) {
            self.referenceDate = referenceDate
            dateComponents = Calendar.current.dateComponents(sortMode.calendarComponents, from: referenceDate)
            self.sortMode = sortMode
        }

        func isContentEqual(to source: Group) -> Bool {
            return referenceDate == source.referenceDate && dateComponents == source.dateComponents && sortMode == source.sortMode
        }
    }

    private static let emptySections = [Section(model: Group(referenceDate: Date(), sortMode: .day), elements: [])]

    var sections = emptySections
    private var moreComing = false
    private var nextCursor: String?
    private var sortMode: PhotoSortMode = UserDefaults.shared.photoSortMode {
        didSet { sortingChanged() }
    }

    var onReloadWithChangeset: ((StagedChangeset<[PhotoListViewModel.Section]>, ([PhotoListViewModel.Section]) -> Void) -> Void)?

    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        super.init(configuration: Configuration(normalFolderHierarchy: false,
                                                showUploadingFiles: false,
                                                selectAllSupported: false,
                                                rootTitle: KDriveResourcesStrings.Localizable.galleryTitle,
                                                emptyViewType: .noImages,
                                                rightBarButtons: [.search, .photoSort],
                                                matomoViewPath: [MatomoUtils.Views.menu.displayName, "PhotoList"]),
                   driveFileManager: driveFileManager,
                   currentDirectory: DriveFileManager.lastPicturesRootFile)

        let fetchedFiles = driveFileManager.fetchResults(ofType: File.self) { faultedCollection in
            faultedCollection
                .filter("extensionType IN %@", [ConvertedType.image.rawValue, ConvertedType.video.rawValue])
                .sorted(by: [SortType.newer.value.sortDescriptor])
        }

        files = AnyRealmCollection(fetchedFiles)
    }

    func loadNextPageIfNeeded() async throws {
        if !isLoading && moreComing {
            try await loadFiles(cursor: nextCursor)
        }
    }

    override func getFile(at indexPath: IndexPath) -> File? {
        guard indexPath.section < sections.count else {
            return nil
        }
        let pictures = sections[indexPath.section].elements
        guard indexPath.row < pictures.count else {
            return nil
        }
        return pictures[indexPath.row]
    }

    override func updateRealmObservation() {
        realmObservationToken?.invalidate()
        realmObservationToken = files.observe(keyPaths: ["lastModifiedAt", "supportedBy"], on: .main) { [weak self] change in
            guard let self else {
                return
            }

            guard let onReloadWithChangeset else {
                // We invalidate observation if we are not able to communicate with the view, as it would break diff sync.
                realmObservationToken?.invalidate()
                SentryDebug.viewModelObservationError()
                return
            }

            switch change {
            case .initial(let results):
                _frozenFiles = AnyRealmCollection(results.freezeIfNeeded())
                let changeset = insertAndSort(pictures: results.freeze())
                onReloadWithChangeset(changeset) { newSections in
                    self.sections = newSections
                }
            case .update(let results, deletions: _, insertions: _, modifications: _):
                _frozenFiles = AnyRealmCollection(results.freezeIfNeeded())
                let changeset = insertAndSort(pictures: results.freeze())
                onReloadWithChangeset(changeset) { newSections in
                    self.sections = newSections
                }
            case .error(let error):
                DDLogError("[Realm Observation] Error \(error)")
            }
        }
    }

    override func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        guard !isLoading || cursor != nil else { return }

        startRefreshing(cursor: cursor)
        defer {
            endRefreshing()
        }

        let (_, nextCursor) = try await driveFileManager.lastPictures(cursor: cursor)
        self.nextCursor = nextCursor
    }

    override func barButtonPressed(type: FileListBarButtonType) {
        if type == .search {
            let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager, filters: Filters(fileType: .image))
            let searchViewController = SearchViewController.instantiateInNavigationController(viewModel: viewModel)
            onPresentViewController?(.modal, searchViewController, true)
        } else if type == .photoSort {
            let floatingPanelViewController = FloatingPanelSelectOptionViewController<PhotoSortMode>
                .instantiatePanel(options: PhotoSortMode.allCases, selectedOption: sortMode,
                                  headerTitle: KDriveResourcesStrings.Localizable.sortTitle,
                                  delegate: self)
            onPresentViewController?(.modal, floatingPanelViewController, true)
        } else {
            super.barButtonPressed(type: type)
        }
    }

    override func didSelect(option: Selectable) {
        guard let mode = option as? PhotoSortMode else { return }
        sortMode = mode
    }

    override func sortingChanged() {
        UserDefaults.shared.photoSortMode = sortMode
        updateRealmObservation()
    }

    private func insertAndSort(pictures: AnyRealmCollection<File>) -> StagedChangeset<[PhotoListViewModel.Section]> {
        var newSections = PhotoListViewModel.emptySections
        for picture in pictures {
            let currentDateComponents = Calendar.current.dateComponents(sortMode.calendarComponents, from: picture.lastModifiedAt)

            var currentSectionIndex: Int!
            if newSections.last?.model.dateComponents == currentDateComponents {
                currentSectionIndex = newSections.count - 1
            } else if let yearMonthIndex = newSections.firstIndex(where: { $0.model.dateComponents == currentDateComponents }) {
                currentSectionIndex = yearMonthIndex
            } else {
                newSections.append(Section(model: Group(referenceDate: picture.lastModifiedAt, sortMode: sortMode), elements: []))
                currentSectionIndex = newSections.count - 1
            }
            newSections[currentSectionIndex].elements.append(picture)
        }

        return StagedChangeset(source: sections, target: newSections)
    }
}
