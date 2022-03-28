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
            self.dateComponents = Calendar.current.dateComponents(sortMode.calendarComponents, from: referenceDate)
            self.sortMode = sortMode
        }

        func isContentEqual(to source: Group) -> Bool {
            return referenceDate == source.referenceDate && dateComponents == source.dateComponents && sortMode == source.sortMode
        }
    }

    private static let emptySections = [Section(model: Group(referenceDate: Date(), sortMode: .day), elements: [])]

    var sections = emptySections
    private var moreComing = false
    private var currentPage = 1
    private var sortMode: PhotoSortMode = UserDefaults.shared.photoSortMode {
        didSet { updateSort() }
    }

    var onReloadWithChangeset: ((StagedChangeset<[PhotoListViewModel.Section]>, ([PhotoListViewModel.Section]) -> Void) -> Void)?

    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        super.init(configuration: Configuration(normalFolderHierarchy: false,
                                                showUploadingFiles: false,
                                                selectAllSupported: false,
                                                rootTitle: KDriveResourcesStrings.Localizable.allPictures,
                                                emptyViewType: .noImages,
                                                rightBarButtons: [.search, .photoSort],
                                                matomoViewPath: [MatomoUtils.Views.menu.displayName, "PhotoList"]),
                   driveFileManager: driveFileManager,
                   currentDirectory: DriveFileManager.lastPicturesRootFile)
        self.files = AnyRealmCollection(driveFileManager.getRealm()
            .objects(File.self)
            .filter(NSPredicate(format: "extensionType = %@", ConvertedType.image.rawValue))
            .sorted(by: [SortType.newer.value.sortDescriptor]))
    }

    func loadNextPageIfNeeded() async throws {
        if !isLoading && moreComing {
            try await loadFiles(page: currentPage + 1)
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
        realmObservationToken = files.observe(on: .main) { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial(let results):
                let results = AnyRealmCollection(results)
                self.files = results
                let changeset = self.insertAndSort(pictures: results.freeze())
                self.onReloadWithChangeset?(changeset) { newSections in
                    self.sections = newSections
                }
            case .update(let results, deletions: _, insertions: _, modifications: _):
                self.files = AnyRealmCollection(results)
                let changeset = self.insertAndSort(pictures: results.freeze())
                self.onReloadWithChangeset?(changeset) { newSections in
                    self.sections = newSections
                }
            case .error(let error):
                DDLogError("[Realm Observation] Error \(error)")
            }
        }
    }

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) async throws {
        guard !isLoading || page > 1 else { return }

        startRefreshing(page: page)
        defer {
            endRefreshing()
        }

        (_, moreComing) = try await driveFileManager.lastPictures(page: page)
        currentPage = page
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

    private func updateSort() {
        UserDefaults.shared.photoSortMode = sortMode
        let changeset = insertAndSort(pictures: files)
        onReloadWithChangeset?(changeset) { newSections in
            self.sections = newSections
        }
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
