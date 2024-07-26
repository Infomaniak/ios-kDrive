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

import DifferenceKit
import Foundation
import InfomaniakCore
import kDriveCore
import kDriveResources
import RealmSwift

class SearchFilesViewModel: FileListViewModel {
    typealias SearchCompletedCallback = (String?) -> Void
    typealias Callback = () -> Void

    private let minSearchCount = 1

    var onSearchCompleted: SearchCompletedCallback?
    var onFiltersChanged: Callback?
    var onContentTypeChanged: Callback?

    var currentSearchText: String? {
        didSet {
            search()
        }
    }

    var filters: Filters {
        didSet {
            search()
        }
    }

    var isDisplayingSearchResults: Bool {
        let displayingSearchResults = (currentSearchText ?? "").count >= minSearchCount || filters.hasFilters
        _isDisplayingSearchResults = displayingSearchResults
        return displayingSearchResults
    }

    /// Detect flip/flop of displayed content type
    var _isDisplayingSearchResults = true {
        willSet {
            guard newValue != _isDisplayingSearchResults else {
                return
            }

            onContentTypeChanged?()
        }
    }

    private var currentTask: Task<Void, Never>?

    private var nextCursor: String?

    convenience init(driveFileManager: DriveFileManager, filters: Filters = Filters()) {
        self.init(driveFileManager: driveFileManager, currentDirectory: nil)
        self.filters = filters
    }

    required init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        let configuration = Configuration(normalFolderHierarchy: false,
                                          showUploadingFiles: false,
                                          isMultipleSelectionEnabled: false,
                                          rootTitle: KDriveResourcesStrings.Localizable.searchTitle,
                                          emptyViewType: .noSearchResults,
                                          leftBarButtons: [.cancel],
                                          rightBarButtons: [.searchFilters],
                                          sortingOptions: [.newer, .older, .relevance],
                                          matomoViewPath: [MatomoUtils.Views.search.displayName])
        filters = Filters()
        let searchFakeRoot = driveFileManager.getManagedFile(from: DriveFileManager.searchFilesRootFile)
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: searchFakeRoot)
        files = AnyRealmCollection(AnyRealmCollection(searchFakeRoot.children).sorted(by: [sortType.value.sortDescriptor]))
    }

    override func startObservation() {
        super.startObservation()
        // Overriding default behavior to change list style in recent searches
        listStyleObservation?.cancel()
        listStyleObservation = nil
        listStyle = .list
        // Custom sort type
        sortTypeObservation?.cancel()
        sortTypeObservation = nil
        sortType = .newer
        sortingChanged()
    }

    override func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        guard isDisplayingSearchResults else { return }

        if ReachabilityListener.instance.currentStatus == .offline {
            searchOffline()
        } else {
            startRefreshing(cursor: cursor)

            do {
                (_, nextCursor) = try await driveFileManager.searchFile(query: currentSearchText,
                                                                        date: filters.date?.dateInterval,
                                                                        fileType: filters.fileType,
                                                                        categories: Array(filters.categories),
                                                                        fileExtensions: filters.fileExtensions,
                                                                        belongToAllCategories: filters.belongToAllCategories,
                                                                        cursor: cursor,
                                                                        sortType: sortType)
                endRefreshing()
            } catch let error as DriveError where error == .networkError {
                searchOffline()
                endRefreshing()
            }
        }

        guard isDisplayingSearchResults else {
            throw DriveError.searchCancelled
        }
    }

    func loadNextPageIfNeeded() async throws {
        guard isDisplayingSearchResults && !isLoading else { return }

        if let nextCursor {
            try await loadFiles(cursor: nextCursor)
        }
    }

    nonisolated func cancelSearch() {
        Task {
            await currentTask?.cancel()
        }
    }

    private func searchOffline() {
        files = AnyRealmCollection(driveFileManager.searchOffline(query: currentSearchText,
                                                                  date: filters.date?.dateInterval,
                                                                  fileType: filters.fileType,
                                                                  categories: Array(filters.categories),
                                                                  fileExtensions: filters.fileExtensions,
                                                                  belongToAllCategories: filters.belongToAllCategories,
                                                                  sortType: sortType))
        startObservation()
    }

    override func barButtonPressed(type: FileListBarButtonType) {
        if type == .searchFilters {
            let navigationController = SearchFiltersViewController
                .instantiateInNavigationController(driveFileManager: driveFileManager)
            let searchFiltersViewController = navigationController.topViewController as? SearchFiltersViewController
            searchFiltersViewController?.filters = filters
            searchFiltersViewController?.delegate = self
            onPresentViewController?(.modal, navigationController, true)
        } else {
            super.barButtonPressed(type: type)
        }
    }

    override func didSelect(option: Selectable) {
        guard let type = option as? SortType else { return }
        sortType = type
        sortingChanged()
    }

    override func listStyleButtonPressed() {
        // Restore observation behavior
        listStyle = listStyle == .grid ? .list : .grid
        FileListOptions.instance.currentStyle = listStyle
    }

    override func sortingChanged() {
        driveFileManager.removeSearchChildren()
        files = AnyRealmCollection(files.sorted(by: [sortType.value.sortDescriptor]))
        search()
    }

    private func search() {
        onFiltersChanged?()
        currentTask?.cancel()
        let newListStyle = isDisplayingSearchResults ? UserDefaults.shared.listStyle : .list
        if listStyle != newListStyle {
            listStyle = newListStyle
        }
        if currentSearchText?.isEmpty != false {
            driveFileManager.removeSearchChildren()
        }
        if isDisplayingSearchResults {
            currentTask = Task {
                try? await loadFiles(cursor: nil, forceRefresh: true)
            }
        }
    }
}

// MARK: Search filters delegate

extension SearchFilesViewModel: SearchFiltersDelegate {
    func didUpdateFilters(_ filters: Filters) {
        self.filters = filters
    }
}

extension String: Differentiable {}

// MARK: - RecentSearchesViewModel

@MainActor
class RecentSearchesViewModel {
    private let maxRecentSearch = 5

    var onReloadWithChangeset: ((StagedChangeset<[String]>, ([String]) -> Void) -> Void)?

    private(set) var recentSearches = UserDefaults.shared.recentSearches {
        didSet {
            UserDefaults.shared.recentSearches = recentSearches
        }
    }

    func add(searchTerm: String) {
        guard !searchTerm.isEmpty else { return }
        var newRecentSearches = recentSearches
        newRecentSearches.removeAll { $0 == searchTerm }
        newRecentSearches.insert(searchTerm, at: 0)
        if newRecentSearches.count > maxRecentSearch {
            newRecentSearches.removeLast()
        }
        update(newRecentSearches: newRecentSearches)
    }

    func remove(searchTerm: String) {
        guard let index = recentSearches.firstIndex(where: { $0 == searchTerm }) else { return }
        var newRecentSearches = recentSearches
        newRecentSearches.remove(at: index)
        update(newRecentSearches: newRecentSearches)
    }

    private func update(newRecentSearches: [String]) {
        let stagedChangeset = StagedChangeset(source: recentSearches, target: newRecentSearches)
        onReloadWithChangeset?(stagedChangeset) { data in
            recentSearches = data
        }
    }
}
