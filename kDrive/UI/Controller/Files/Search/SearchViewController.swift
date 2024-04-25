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

// MARK: - SearchViewController

class SearchViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.search }
    override class var storyboardIdentifier: String { "SearchViewController" }

    // MARK: - Constants

    private let minSearchCount = 1
    private let searchHeaderIdentifier = "BasicTitleCollectionReusableView"
    private let sectionTitles = [
        KDriveResourcesStrings.Localizable.searchLastTitle,
        KDriveResourcesStrings.Localizable.searchFilterTitle
    ]
    private let searchController = UISearchController(searchResultsController: nil)
    private let recentSearchesViewModel = RecentSearchesViewModel()

    // MARK: - Properties

    private var searchViewModel: SearchFilesViewModel! {
        return viewModel as? SearchFilesViewModel
    }

    deinit {
        searchViewModel.cancelSearch()
    }

    // MARK: - View controller lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(
            UINib(nibName: searchHeaderIdentifier, bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: searchHeaderIdentifier
        )
        collectionView.register(cellView: RecentSearchCollectionViewCell.self)
        collectionView.keyboardDismissMode = .onDrag

        searchController.hidesNavigationBarDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.isActive = true
        searchController.searchBar.showsCancelButton = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = KDriveResourcesStrings.Localizable.searchViewHint
        searchController.searchBar.delegate = self

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        definesPresentationContext = true

        bindSearchViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { @MainActor in
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
            guard let self else { return }
            if searchViewModel.isDisplayingSearchResults {
                // We don't reload the collection view but we still need to set the data
                if let data = stagedChangeset.last?.data {
                    setData(data)
                }
            } else {
                collectionView.reload(using: stagedChangeset, setData: setData)
                collectionView.reloadCorners(insertions: stagedChangeset.last?.elementInserted.map(\.element) ?? [],
                                             deletions: stagedChangeset.last?.elementDeleted.map(\.element) ?? [],
                                             count: recentSearchesViewModel.recentSearches.count)
            }
        }

        // Clear collection view on content type changed without animation
        searchViewModel.onContentTypeChanged = { [weak self] in
            guard let self else { return }
            collectionView.reloadData()
        }

        searchViewModel.onFiltersChanged = { [weak self] in
            guard let self else { return }
            guard isViewLoaded else { return }
            // Update UI
            collectionView.refreshControl = searchViewModel.isDisplayingSearchResults ? refreshControl : nil
            collectionViewLayout?.sectionHeadersPinToVisibleBounds = searchViewModel.isDisplayingSearchResults
            collectionView.backgroundView = nil
            if let headerView {
                updateFilters(headerView: headerView)
            }
            collectionView.performBatchUpdates(nil)
        }

        searchViewModel.onSearchCompleted = { [weak self] searchTerm in
            guard let searchTerm else { return }
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

    override func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if searchViewModel.isDisplayingSearchResults {
            return super.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
        } else {
            let titleHeaderView = collectionView.dequeueReusableSupplementaryView(
                ofKind: UICollectionView.elementKindSectionHeader,
                withReuseIdentifier: searchHeaderIdentifier,
                for: indexPath
            ) as! BasicTitleCollectionReusableView
            titleHeaderView.titleLabel.text = sectionTitles[indexPath.section]
            return titleHeaderView
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if searchViewModel.isDisplayingSearchResults {
            return super.collectionView(collectionView, cellForItemAt: indexPath)
        } else {
            let cell = collectionView.dequeueReusableCell(type: RecentSearchCollectionViewCell.self, for: indexPath)
            cell.initStyle(
                isFirst: indexPath.row == 0,
                isLast: indexPath.row == self.collectionView(collectionView, numberOfItemsInSection: indexPath.section) - 1
            )
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
            searchViewModel.onSearchCompleted?(searchViewModel.currentSearchText)
        } else {
            let searchTerm = recentSearchesViewModel.recentSearches[indexPath.row]
            searchViewModel.currentSearchText = searchTerm
            searchController.searchBar.text = searchTerm
        }
    }

    // MARK: - Collection view delegate flow layout

    override func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        if searchViewModel.isDisplayingSearchResults {
            return super.collectionView(collectionView, layout: collectionViewLayout, referenceSizeForHeaderInSection: section)
        } else {
            if recentSearchesViewModel.recentSearches.isEmpty {
                return .zero
            } else {
                let view = self.collectionView(
                    collectionView,
                    viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionHeader,
                    at: IndexPath(row: 0, section: section)
                )
                return view.systemLayoutSizeFitting(
                    CGSize(width: collectionView.frame.width, height: UIView.layoutFittingCompressedSize.height),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
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

    override func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        if searchViewModel.isDisplayingSearchResults {
            return super.collectionView(collectionView, itemsForBeginning: session, at: indexPath)
        } else {
            return []
        }
    }
}

// MARK: - Search end editing

extension SearchViewController: UISearchBarDelegate {
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchViewModel.onSearchCompleted?(searchViewModel.currentSearchText)
    }
}

// MARK: - Search results updating

extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchViewModel.currentSearchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces)
    }
}
