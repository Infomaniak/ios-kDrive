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
import kDriveCore
import kDriveResources
import UIKit

class SearchViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.search }
    override class var storyboardIdentifier: String { "SearchViewController" }

    // MARK: - Constants

    private let minSearchCount = 1
    private let maxRecentSearch = 5
    private let searchHeaderIdentifier = "BasicTitleCollectionReusableView"
    private let sectionTitles = [KDriveResourcesStrings.Localizable.searchLastTitle, KDriveResourcesStrings.Localizable.searchFilterTitle]

    // MARK: - Properties

    private let searchController = UISearchController(searchResultsController: nil)
    private var currentSearchText: String? {
        didSet { updateList() }
    }

    private var filters = Filters() {
        didSet { updateList() }
    }

    private var isDisplayingSearchResults: Bool {
        (currentSearchText ?? "").count >= minSearchCount || filters.hasFilters
    }

    private var recentSearches = UserDefaults.shared.recentSearches
    private var currentRequest: DataRequest?

    // MARK: - View controller lifecycle

    override func viewDidLoad() {
        // Set configuration
        configuration = Configuration(normalFolderHierarchy: false, showUploadingFiles: false, isMultipleSelectionEnabled: false, isRefreshControlEnabled: false, rootTitle: KDriveResourcesStrings.Localizable.searchTitle, emptyViewType: .noSearchResults)
        listStyle = .list
        sortType = .newer

        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)

        collectionView.register(UINib(nibName: searchHeaderIdentifier, bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: searchHeaderIdentifier)
        collectionView.keyboardDismissMode = .onDrag

        searchController.hidesNavigationBarDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.isActive = true
        searchController.searchBar.showsCancelButton = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = KDriveResourcesStrings.Localizable.searchViewHint

        navigationItem.searchController = searchController
        navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose

        definesPresentationContext = true

        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            self.searchController.searchBar.becomeFirstResponder()
        }
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        guard isDisplayingSearchResults && driveFileManager != nil else {
            DispatchQueue.main.async {
                completion(.failure(DriveError.searchCancelled), false, true)
            }
            return
        }

        currentRequest = driveFileManager.searchFile(query: currentSearchText, date: filters.date?.dateInterval, fileType: filters.fileType?.rawValue, categories: Array(filters.categories), belongToAllCategories: filters.belongToAllCategories, page: page, sortType: sortType) { [currentSearchText] file, children, error in
            guard self.isDisplayingSearchResults else {
                completion(.failure(DriveError.searchCancelled), false, false)
                return
            }

            if let currentSearchText = currentSearchText {
                self.addToRecentSearch(currentSearchText)
            }
            if let fetchedCurrentDirectory = file, let fetchedChildren = children {
                completion(.success(fetchedChildren), !fetchedCurrentDirectory.fullyDownloaded, false)
            } else {
                completion(.failure(error ?? DriveError.localError), false, false)
            }
        }
    }

    override func getNewChanges() {
        // We don't have incremental changes for search
    }

    override func setUpHeaderView(_ headerView: FilesHeaderView, isListEmpty: Bool) {
        super.setUpHeaderView(headerView, isListEmpty: isListEmpty)
        // Set up filter header view
        if filters.hasFilters {
            headerView.filterView.isHidden = false
            headerView.filterView.configure(with: filters)
        } else {
            headerView.filterView.isHidden = true
        }
    }

    static func instantiateInNavigationController(driveFileManager: DriveFileManager, filters: Filters = Filters()) -> UINavigationController {
        let searchViewController = instantiate(driveFileManager: driveFileManager)
        searchViewController.filters = filters
        let navigationController = UINavigationController(rootViewController: searchViewController)
        navigationController.modalPresentationStyle = .fullScreen
        return navigationController
    }

    // MARK: - Actions

    @IBAction func closeButtonPressed() {
        searchController.dismiss(animated: true)
        dismiss(animated: true)
    }

    // MARK: - Private methods

    private func addToRecentSearch(_ search: String) {
        if search.count > minSearchCount && !recentSearches.contains(search) {
            recentSearches.insert(search, at: 0)
            if recentSearches.count > maxRecentSearch {
                recentSearches.removeLast()
            }
            UserDefaults.shared.recentSearches = recentSearches
        }
    }

    private func updateList() {
        guard isViewLoaded else { return }
        // Update UI
        listStyle = isDisplayingSearchResults ? UserDefaults.shared.listStyle : .list
        collectionView.refreshControl = isDisplayingSearchResults ? refreshControl : nil
        collectionViewLayout?.sectionHeadersPinToVisibleBounds = isDisplayingSearchResults
        sortedFiles = []
        collectionView.backgroundView = nil
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
        currentRequest?.cancel()
        currentRequest = nil
        isLoadingData = false
        if isDisplayingSearchResults {
            forceRefresh()
        }
    }

    // MARK: - Collection view data source

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isDisplayingSearchResults {
            return super.collectionView(collectionView, numberOfItemsInSection: section)
        } else {
            switch section {
            case 0:
                return recentSearches.count
            default:
                return 0
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if isDisplayingSearchResults {
            return super.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
        } else {
            let titleHeaderView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: searchHeaderIdentifier, for: indexPath) as! BasicTitleCollectionReusableView
            titleHeaderView.titleLabel.text = sectionTitles[indexPath.section]
            return titleHeaderView
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isDisplayingSearchResults {
            return super.collectionView(collectionView, cellForItemAt: indexPath)
        } else {
            let cell = collectionView.dequeueReusableCell(type: FileCollectionViewCell.self, for: indexPath)
            cell.initStyle(isFirst: indexPath.row == 0, isLast: indexPath.row == self.collectionView(collectionView, numberOfItemsInSection: indexPath.section) - 1)
            cell.moreButton.isHidden = true
            let recentSearch = recentSearches[indexPath.row]
            cell.configureWith(recentSearch: recentSearch)

            return cell
        }
    }

    // MARK: - Collection view delegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isDisplayingSearchResults {
            super.collectionView(collectionView, didSelectItemAt: indexPath)
        } else {
            switch indexPath.section {
            case 0:
                currentSearchText = recentSearches[indexPath.row]
                searchController.searchBar.text = currentSearchText
            default:
                break
            }
        }
    }

    // MARK: - Collection view delegate flow layout

    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if isDisplayingSearchResults {
            return super.collectionView(collectionView, layout: collectionViewLayout, referenceSizeForHeaderInSection: section)
        } else {
            if section == 0 && recentSearches.isEmpty {
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
            filters.date = nil
        } else if filter is ConvertedType {
            filters.fileType = nil
        } else if let category = filter as? kDriveCore.Category {
            filters.categories.remove(category)
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "filterSegue" {
            let navigationController = segue.destination as? UINavigationController
            let searchFiltersViewController = navigationController?.topViewController as? SearchFiltersViewController
            searchFiltersViewController?.driveFileManager = driveFileManager
            searchFiltersViewController?.filters = filters
            searchFiltersViewController?.delegate = self
        }
    }
}

// MARK: - Search results updating

extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        currentSearchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Search filters delegate

extension SearchViewController: SearchFiltersDelegate {
    func didUpdateFilters(_ filters: Filters) {
        self.filters = filters
    }
}
