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

import Alamofire
import DifferenceKit
import InfomaniakCore
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

extension String: Differentiable {}

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
        guard !searchTerm.isEmpty && !recentSearches.contains(searchTerm) else { return }
        var newRecentSearches = recentSearches
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

class SearchFilesViewModel: FileListViewModel {
    typealias SearchCompletedCallback = (String?) -> Void
    typealias FiltersChangedCallback = () -> Void

    private let minSearchCount = 1

    var onSearchCompleted: SearchCompletedCallback?
    var onFiltersChanged: FiltersChangedCallback?

    var currentSearchText: String? {
        didSet { search() }
    }

    var filters: Filters {
        didSet { search() }
    }

    var isDisplayingSearchResults: Bool {
        (currentSearchText ?? "").count >= minSearchCount || filters.hasFilters
    }

    private var currentTask: Task<Void, Never>?

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
                                          matomoViewPath: [MatomoUtils.Views.search.displayName])
        filters = Filters()
        let searchFakeRoot = driveFileManager.getManagedFile(from: DriveFileManager.searchFilesRootFile)
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: searchFakeRoot)
        files = AnyRealmCollection(AnyRealmCollection(searchFakeRoot.children).filesSorted(by: sortType))
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

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) async throws {
        guard isDisplayingSearchResults else { return }

        var moreComing = false
        if ReachabilityListener.instance.currentStatus == .offline {
            searchOffline()
        } else {
            do {
                moreComing = try await driveFileManager.searchFile(query: currentSearchText,
                                                                   date: filters.date?.dateInterval,
                                                                   fileType: filters.fileType,
                                                                   categories: Array(filters.categories),
                                                                   belongToAllCategories: filters.belongToAllCategories,
                                                                   page: page,
                                                                   sortType: sortType)
            } catch {
                if let error = error as? DriveError,
                   error == .networkError {
                    // Maybe warn the user that the search will be incomplete ?
                    searchOffline()
                } else {
                    throw error
                }
            }
        }

        guard isDisplayingSearchResults else {
            throw DriveError.searchCancelled
        }

        endRefreshing()
        if moreComing {
            try await loadFiles(page: page + 1)
        }
    }

    private func searchOffline() {
        files = AnyRealmCollection(driveFileManager.searchOffline(query: currentSearchText,
                                                                  date: filters.date?.dateInterval,
                                                                  fileType: filters.fileType,
                                                                  categories: Array(filters.categories),
                                                                  belongToAllCategories: filters.belongToAllCategories,
                                                                  sortType: sortType))
        startObservation()
    }

    override func barButtonPressed(type: FileListBarButtonType) {
        if type == .searchFilters {
            let navigationController = SearchFiltersViewController.instantiateInNavigationController(driveFileManager: driveFileManager)
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

    private func search() {
        onFiltersChanged?()
        currentTask?.cancel()
        // listStyle = isDisplayingSearchResults ? UserDefaults.shared.listStyle : .list
        if currentSearchText?.isEmpty != false {
            driveFileManager.removeSearchChildren()
        }
        if isDisplayingSearchResults {
            currentTask = Task { [currentSearchText] in
                try? await loadFiles(page: 1, forceRefresh: true)
                onSearchCompleted?(currentSearchText)
            }
        }
    }
}

// MARK: - Search filters delegate

extension SearchFilesViewModel: SearchFiltersDelegate {
    func didUpdateFilters(_ filters: Filters) {
        self.filters = filters
    }
}

class SearchViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.search }
    override class var storyboardIdentifier: String { "SearchViewController" }

    // MARK: - Constants

    private let minSearchCount = 1
    private let searchHeaderIdentifier = "BasicTitleCollectionReusableView"
    private let sectionTitles = [KDriveResourcesStrings.Localizable.searchLastTitle, KDriveResourcesStrings.Localizable.searchFilterTitle]
    private let searchController = UISearchController(searchResultsController: nil)
    private let recentSearchesViewModel = RecentSearchesViewModel()

    // MARK: - Properties

    private var searchViewModel: SearchFilesViewModel! {
        return viewModel as? SearchFilesViewModel
    }

    // MARK: - View controller lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(UINib(nibName: searchHeaderIdentifier, bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: searchHeaderIdentifier)
        collectionView.register(cellView: RecentSearchCollectionViewCell.self)
        collectionView.keyboardDismissMode = .onDrag

        searchController.hidesNavigationBarDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.isActive = true
        searchController.searchBar.showsCancelButton = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = KDriveResourcesStrings.Localizable.searchViewHint

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        definesPresentationContext = true

        bindSearchViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            self.searchController.searchBar.becomeFirstResponder()
        }
    }

    override func barButtonPressed(_ sender: FileListBarButton) {
        if sender.type == .cancel {
            searchController.dismiss(animated: true)
            dismiss(animated: true)
        } else {
            super.barButtonPressed(sender)
        }
    }

    override func setUpHeaderView(_ headerView: FilesHeaderView, isEmptyViewHidden: Bool) {
        super.setUpHeaderView(headerView, isEmptyViewHidden: isEmptyViewHidden)
        // Set up filter header view
        updateFilters(headerView: headerView)
    }

    static func instantiateInNavigationController(viewModel: SearchFilesViewModel) -> UINavigationController {
        let searchViewController = instantiate(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: searchViewController)
        navigationController.modalPresentationStyle = .fullScreen
        return navigationController
    }

    // MARK: - Private methods

    private func bindSearchViewModel() {
        recentSearchesViewModel.onReloadWithChangeset = { [weak self] stagedChangeset, setData in
            if self?.searchViewModel.isDisplayingSearchResults == false {
                self?.collectionView.reload(using: stagedChangeset, setData: setData)
                self?.reloadCorners(insertions: stagedChangeset.last?.elementInserted.map(\.element) ?? [],
                                    deletions: stagedChangeset.last?.elementDeleted.map(\.element) ?? [],
                                    count: self?.recentSearchesViewModel.recentSearches.count ?? 0)
            } else {
                // We don't reload the collection view but we still need to set the data
                if let data = stagedChangeset.last?.data {
                    setData(data)
                }
            }
        }

        searchViewModel.onFiltersChanged = { [weak self] in
            guard let self = self, self.isViewLoaded else { return }
            // Update UI
            self.collectionView.refreshControl = self.searchViewModel.isDisplayingSearchResults ? self.refreshControl : nil
            self.collectionViewLayout?.sectionHeadersPinToVisibleBounds = self.searchViewModel.isDisplayingSearchResults
            self.collectionView.backgroundView = nil
            if let headerView = self.headerView {
                self.updateFilters(headerView: headerView)
            }
            self.collectionView.performBatchUpdates(nil)
        }

        searchViewModel.onSearchCompleted = { [weak self] searchTerm in
            guard let searchTerm = searchTerm else { return }
            self?.recentSearchesViewModel.add(searchTerm: searchTerm)
        }
    }

    private func updateFilters(headerView: FilesHeaderView) {
        if searchViewModel.filters.hasFilters {
            headerView.filterView.isHidden = false
            headerView.filterView.configure(with: searchViewModel.filters)
        } else {
            headerView.filterView.isHidden = true
        }
    }

    override func updateFileList(deletions: [Int], insertions: [Int], modifications: [Int], moved: [(source: Int, target: Int)]) {
        guard searchViewModel.isDisplayingSearchResults else {
            return
        }
        super.updateFileList(deletions: deletions, insertions: insertions, modifications: modifications, moved: moved)
    }

    override func showEmptyView(_ isHidden: Bool) {
        guard searchViewModel.isDisplayingSearchResults else {
            return
        }
        super.showEmptyView(isHidden)
    }

    // MARK: - Collection view data source

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if searchViewModel.isDisplayingSearchResults {
            return super.collectionView(collectionView, numberOfItemsInSection: section)
        } else {
            return recentSearchesViewModel.recentSearches.count
        }
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if searchViewModel.isDisplayingSearchResults {
            return super.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
        } else {
            let titleHeaderView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: searchHeaderIdentifier, for: indexPath) as! BasicTitleCollectionReusableView
            titleHeaderView.titleLabel.text = sectionTitles[indexPath.section]
            return titleHeaderView
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if searchViewModel.isDisplayingSearchResults {
            return super.collectionView(collectionView, cellForItemAt: indexPath)
        } else {
            let cell = collectionView.dequeueReusableCell(type: RecentSearchCollectionViewCell.self, for: indexPath)
            cell.initStyle(isFirst: indexPath.row == 0, isLast: indexPath.row == self.collectionView(collectionView, numberOfItemsInSection: indexPath.section) - 1)
            let recentSearch = recentSearchesViewModel.recentSearches[indexPath.row]
            cell.configureWith(recentSearch: recentSearch)
            cell.removeButtonHandler = { [weak self] _ in
                self?.recentSearchesViewModel.remove(searchTerm: recentSearch)
            }
            return cell
        }
    }

    // MARK: - Collection view delegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if searchViewModel.isDisplayingSearchResults {
            super.collectionView(collectionView, didSelectItemAt: indexPath)
        } else {
            let searchTerm = recentSearchesViewModel.recentSearches[indexPath.row]
            searchViewModel.currentSearchText = searchTerm
            searchController.searchBar.text = searchTerm
        }
    }

    // MARK: - Collection view delegate flow layout

    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if searchViewModel.isDisplayingSearchResults {
            return super.collectionView(collectionView, layout: collectionViewLayout, referenceSizeForHeaderInSection: section)
        } else {
            if recentSearchesViewModel.recentSearches.isEmpty {
                return .zero
            } else {
                let view = self.collectionView(collectionView, viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionHeader, at: IndexPath(row: 0, section: section))
                return view.systemLayoutSizeFitting(CGSize(width: collectionView.frame.width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            }
        }
    }

    // MARK: - Files header view delegate

    override func removeFilterButtonPressed(_ filter: Filterable) {
        if filter is DateOption {
            searchViewModel.filters.date = nil
        } else if filter is ConvertedType {
            searchViewModel.filters.fileType = nil
        } else if let category = filter as? kDriveCore.Category {
            searchViewModel.filters.categories.remove(category)
        }
        collectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: - UICollectionViewDragDelegate

    override func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        if searchViewModel.isDisplayingSearchResults {
            return super.collectionView(collectionView, itemsForBeginning: session, at: indexPath)
        } else {
            return []
        }
    }
}

// MARK: - Search results updating

extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchViewModel.currentSearchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces)
    }
}
