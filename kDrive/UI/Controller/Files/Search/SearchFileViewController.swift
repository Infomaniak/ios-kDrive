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

import UIKit
import kDriveCore

public struct FileTypeRow {
    let name: String
    let icon: UIImage
    let type: String
    static let imagesRow = FileTypeRow(name: KDriveStrings.Localizable.allPictures, icon: KDriveAsset.fileImage.image, type: ConvertedType.image.rawValue)
    static let videosRow = FileTypeRow(name: KDriveStrings.Localizable.allVideo, icon: KDriveAsset.fileVideo.image, type: ConvertedType.video.rawValue)
    static let audioRow = FileTypeRow(name: KDriveStrings.Localizable.allAudio, icon: KDriveAsset.fileAudio.image, type: ConvertedType.audio.rawValue)
    static let pdfRow = FileTypeRow(name: KDriveStrings.Localizable.allPdf, icon: KDriveAsset.filePdf.image, type: ConvertedType.pdf.rawValue)
    static let docsRow = FileTypeRow(name: KDriveStrings.Localizable.allOfficeDocs, icon: KDriveAsset.fileText.image, type: ConvertedType.text.rawValue)
    static let pointsRow = FileTypeRow(name: KDriveStrings.Localizable.allOfficePoints, icon: KDriveAsset.filePresentation.image, type: ConvertedType.presentation.rawValue)
    static let gridsRow = FileTypeRow(name: KDriveStrings.Localizable.allOfficeGrids, icon: KDriveAsset.fileSheets.image, type: ConvertedType.spreadsheet.rawValue)
    static let folderRow = FileTypeRow(name: KDriveStrings.Localizable.allFolder, icon: KDriveAsset.folderFilled.image, type: ConvertedType.folder.rawValue)
    static let dropboxRow = FileTypeRow(name: KDriveStrings.Localizable.dropBoxTitle, icon: KDriveAsset.folderDropBox.image, type: "")
}

class SearchFileViewController: FileListCollectionViewController, UISearchBarDelegate {

    private let searchController = UISearchController(searchResultsController: nil)
    private var currentSearchText = ""
    private var isDisplayingSearchResults = false
    private let sectionTitles = [KDriveStrings.Localizable.searchLastTitle, KDriveStrings.Localizable.searchFilterTitle]

    private let fileTypeRows: [FileTypeRow] = [.imagesRow, .videosRow, .audioRow, .pdfRow, .docsRow, .pointsRow, .gridsRow, .folderRow, .dropboxRow]
    private var recentSearches = [String]()
    private var selectedFileType: FileTypeRow?
    private let minSearchCount = 1
    private let maxRecentSearch = 5
    private var showedNetworkError = false

    override var normalFolderHierarchy: Bool {
        return false
    }
    override var showUploadingFiles: Bool {
        return false
    }
    override var isMultipleSelectionEnabled: Bool {
        return false
    }

    override func viewDidLoad() {
        recentSearches = UserDefaults.shared.recentSearches
        collectionView.register(UINib(nibName: "BasicTitleCollectionReusableView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "BasicTitleCollectionReusableView")
        super.viewDidLoad()
        listStyle = .list
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.isActive = true
        searchController.searchBar.showsCancelButton = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = KDriveStrings.Localizable.searchViewHint
        definesPresentationContext = true
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.title = KDriveStrings.Localizable.searchTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
        navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveStrings.Localizable.buttonClose
        sortType = .newer
        collectionView.keyboardDismissMode = .onDrag
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            self.searchController.searchBar.becomeFirstResponder()
        }
    }

    override func addRefreshControl() {
        if isDisplayingSearchResults && collectionView.refreshControl == nil {
            super.addRefreshControl()
        } else if !isDisplayingSearchResults {
            collectionView.refreshControl = nil
        }
    }

    @objc private func closeButtonPressed() {
        searchController.dismiss(animated: true)
        dismiss(animated: true)
    }

    override func getFileActivities(directory: File) {
        //We don't have incremental changes for search
    }

    override func fetchNextPage(forceRefresh: Bool = false) {
        if !isDisplayingSearchResults { return }
        currentPage += 1
        driveFileManager.searchFile(query: currentSearchText, fileType: selectedFileType?.type, page: currentPage, sortType: sortType) { [self] (root, files, error) in
            collectionView.refreshControl?.endRefreshing()
            if !isDisplayingSearchResults { return }
            if let fetchedCurrentDirectory = root,
                let fetchedChildren = files {
                fetchedChildren.first?.isFirstInCollection = true
                fetchedChildren.last?.isLastInCollection = true

                let newChildren = sortedChildren + fetchedChildren
                let changeset = getChangesetFor(newChildren: newChildren)

                if fetchedChildren.isEmpty {
                    let background = EmptyTableView.instantiate(type: .noSearchResults)
                    collectionView.backgroundView = background
                    headerView?.sortView.isHidden = true
                } else {
                    collectionView.backgroundView = nil
                    headerView?.sortView.isHidden = false
                }
                collectionView.reload(using: changeset) { newChildren in
                    sortedChildren = newChildren
                }

                if !fetchedCurrentDirectory.fullyDownloaded && view.window != nil {
                    fetchNextPage()
                }
            } else {
            }
            if let error = error as? DriveError, error == .networkError && !showedNetworkError {
                showedNetworkError = true
                UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorNetwork + ". " + KDriveStrings.Localizable.errorNetworkDescription)
            }
        }
    }

    private func addToRecentSearch(_ search: String) {
        if search.count > minSearchCount && !recentSearches.contains(search) {
            recentSearches.insert(search, at: 0)
            if recentSearches.count > maxRecentSearch {
                recentSearches.removeLast()
            }
            UserDefaults.shared.recentSearches = recentSearches
        }
    }

    override class func instantiate() -> SearchFileViewController {
        return UIStoryboard(name: "Search", bundle: nil).instantiateViewController(withIdentifier: "SearchFileViewController") as! SearchFileViewController
    }

    class func instantiateInNavigationController() -> UINavigationController {
        let searchViewController = instantiate()
        let navigationController = UINavigationController(rootViewController: searchViewController)
        navigationController.modalPresentationStyle = .fullScreen
        return navigationController
    }

    // MARK: - Collection view data source
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return isDisplayingSearchResults ? super.numberOfSections(in: collectionView) : 2
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isDisplayingSearchResults {
            return super.collectionView(collectionView, numberOfItemsInSection: section)
        } else {
            return section == 0 ? recentSearches.count : fileTypeRows.count
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isDisplayingSearchResults {
            return super.collectionView(collectionView, cellForItemAt: indexPath)
        } else {
            let cell = collectionView.dequeueReusableCell(type: FileCollectionViewCell.self, for: indexPath)
            cell.initStyle(isFirst: indexPath.row == 0, isLast: indexPath.row == self.collectionView(collectionView, numberOfItemsInSection: indexPath.section) - 1)
            if indexPath.section == 0 {
                let recentSearch = recentSearches[indexPath.row]
                cell.configureWith(recentSearch: recentSearch)
            } else {
                let fileType = fileTypeRows[indexPath.row]
                cell.configureWith(fileType: fileType)
            }

            return cell
        }
    }

    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if isDisplayingSearchResults {
            return super.collectionView(collectionView, layout: collectionViewLayout, referenceSizeForHeaderInSection: section)
        } else {
            if section == 0 && recentSearches.count == 0 {
                return CGSize.zero
            } else {
                let view = self.collectionView(collectionView, viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionHeader, at: IndexPath(row: 0, section: section))
                return view.systemLayoutSizeFitting(CGSize(width: collectionView.frame.width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if isDisplayingSearchResults {
            let headerView = super.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
            if let headerView = headerView as? FilesHeaderView {
                if let selectedFileType = selectedFileType {
                    headerView.fileTypeFilterView.isHidden = false
                    headerView.fileTypeFilterView.fileTypeIconImageView.image = selectedFileType.icon
                    headerView.fileTypeFilterView.fileTypeLabel.text = selectedFileType.name
                } else {
                    headerView.fileTypeFilterView.isHidden = true
                }
            }
            return headerView
        } else {
            let titleHeaderView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "BasicTitleCollectionReusableView", for: indexPath) as? BasicTitleCollectionReusableView
            titleHeaderView?.titleLabel.text = sectionTitles[indexPath.section]
            return titleHeaderView!
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isDisplayingSearchResults {
            super.collectionView(collectionView, didSelectItemAt: indexPath)
        } else {
            if indexPath.section == 0 {
                currentSearchText = recentSearches[indexPath.row]
                searchController.searchBar.text = currentSearchText
            } else {
                let fileType = fileTypeRows[indexPath.row]
                selectedFileType = fileType
            }
            showResults()
        }
    }

    override func removeFileTypeButtonPressed() {
        selectedFileType = nil
        hideResults()
    }

    private func hideResults() {
        listStyle = .list
        isDisplayingSearchResults = false
        addRefreshControl()
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionHeadersPinToVisibleBounds = isDisplayingSearchResults
        sortedChildren = [File]()
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
    }

    private func showResults() {
        listStyle = UserDefaults.shared.listStyle
        sortedChildren = [File]()
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
        isDisplayingSearchResults = true
        addRefreshControl()
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionHeadersPinToVisibleBounds = isDisplayingSearchResults
        currentPage = 0
        fetchNextPage()
    }

    override func searchButtonPressed(_ sender: Any) {
        if currentSearchText.count > minSearchCount && !recentSearches.contains(currentSearchText) {
            recentSearches.insert(currentSearchText, at: 0)
            if recentSearches.count > maxRecentSearch {
                recentSearches.removeLast()
            }
            UserDefaults.shared.recentSearches = recentSearches
        }
        updateSearchResults(for: searchController)
    }
}

//MARK: UISearchResultsUpdating
extension SearchFileViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text,
            searchText.count >= minSearchCount || selectedFileType != nil {
            if searchText != currentSearchText {
                currentSearchText = searchText
                showResults()
            }
        } else {
            hideResults()
        }
    }

}
