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

public struct FileTypeRow: RawRepresentable {

    public typealias RawValue = String

    public var rawValue: String
    let name: String
    let icon: UIImage
    let type: String

    public init?(rawValue: String) {
        if let type = FileTypeRow.allValues.first(where: { $0.rawValue == rawValue }) {
            self = type
        } else {
            return nil
        }
    }

    init(rawValue: String, name: String, icon: UIImage, type: String) {
        self.rawValue = rawValue
        self.name = name
        self.icon = icon
        self.type = type
    }

    static let imagesRow = FileTypeRow(rawValue: "images", name: KDriveStrings.Localizable.allPictures, icon: KDriveAsset.fileImage.image, type: ConvertedType.image.rawValue)
    static let videosRow = FileTypeRow(rawValue: "videos", name: KDriveStrings.Localizable.allVideo, icon: KDriveAsset.fileVideo.image, type: ConvertedType.video.rawValue)
    static let audioRow = FileTypeRow(rawValue: "audio", name: KDriveStrings.Localizable.allAudio, icon: KDriveAsset.fileAudio.image, type: ConvertedType.audio.rawValue)
    static let pdfRow = FileTypeRow(rawValue: "pdf", name: KDriveStrings.Localizable.allPdf, icon: KDriveAsset.filePdf.image, type: ConvertedType.pdf.rawValue)
    static let docsRow = FileTypeRow(rawValue: "docs", name: KDriveStrings.Localizable.allOfficeDocs, icon: KDriveAsset.fileText.image, type: ConvertedType.text.rawValue)
    static let pointsRow = FileTypeRow(rawValue: "points", name: KDriveStrings.Localizable.allOfficePoints, icon: KDriveAsset.filePresentation.image, type: ConvertedType.presentation.rawValue)
    static let gridsRow = FileTypeRow(rawValue: "grid", name: KDriveStrings.Localizable.allOfficeGrids, icon: KDriveAsset.fileSheets.image, type: ConvertedType.spreadsheet.rawValue)
    static let folderRow = FileTypeRow(rawValue: "folder", name: KDriveStrings.Localizable.allFolder, icon: KDriveAsset.folderFilled.image, type: ConvertedType.folder.rawValue)
    static let dropboxRow = FileTypeRow(rawValue: "dropbox", name: KDriveStrings.Localizable.dropBoxTitle, icon: KDriveAsset.folderDropBox.image, type: "")
    static let allValues = [imagesRow, videosRow, audioRow, pdfRow, docsRow, pointsRow, gridsRow, folderRow, dropboxRow]
}

class SearchViewController: FileListViewController {

    override class var storyboard: UIStoryboard { Storyboard.search }
    override class var storyboardIdentifier: String { "SearchViewController" }

    // MARK: - Constants

    private let minSearchCount = 1
    private let maxRecentSearch = 5
    private let searchHeaderIdentifier = "BasicTitleCollectionReusableView"
    private let sectionTitles = [KDriveStrings.Localizable.searchLastTitle, KDriveStrings.Localizable.searchFilterTitle]
    private let fileTypeRows: [FileTypeRow] = FileTypeRow.allValues

    // MARK: - Properties

    private let searchController = UISearchController(searchResultsController: nil)
    private var currentSearchText: String? {
        didSet { updateList() }
    }
    private var selectedFileType: FileTypeRow? {
        didSet { updateList() }
    }
    private var isDisplayingSearchResults: Bool {
        (currentSearchText ?? "").count >= minSearchCount || selectedFileType != nil
    }
    private var recentSearches = UserDefaults.shared.recentSearches

    // MARK: - View controller lifecycle

    override func viewDidLoad() {
        // Set configuration
        configuration = Configuration(normalFolderHierarchy: false, showUploadingFiles: false, isMultipleSelectionEnabled: false, isRefreshControlEnabled: false, rootTitle: KDriveStrings.Localizable.searchTitle, emptyViewType: .noSearchResults)
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
        searchController.searchBar.placeholder = KDriveStrings.Localizable.searchViewHint

        navigationItem.searchController = searchController
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
        navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveStrings.Localizable.buttonClose

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
            completion(.success([]), false, true)
            return
        }

        driveFileManager.searchFile(query: currentSearchText, fileType: selectedFileType?.type, page: page, sortType: sortType) { file, children, error in
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
        if let selectedFileType = selectedFileType {
            headerView.fileTypeFilterView.isHidden = false
            headerView.fileTypeFilterView.fileTypeIconImageView.image = selectedFileType.icon
            headerView.fileTypeFilterView.fileTypeLabel.text = selectedFileType.name
        } else {
            headerView.fileTypeFilterView.isHidden = true
        }
    }

    static func instantiateInNavigationController(driveFileManager: DriveFileManager, fileType: FileTypeRow? = nil) -> UINavigationController {
        let searchViewController = instantiate(driveFileManager: driveFileManager)
        searchViewController.selectedFileType = fileType
        let navigationController = UINavigationController(rootViewController: searchViewController)
        navigationController.modalPresentationStyle = .fullScreen
        return navigationController
    }

    // MARK: - Actions

    @objc func closeButtonPressed() {
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
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
        if isDisplayingSearchResults {
            forceRefresh()
        }
    }

    // MARK: - Collection view data source

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return isDisplayingSearchResults ? 1 : 2
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isDisplayingSearchResults {
            return super.collectionView(collectionView, numberOfItemsInSection: section)
        } else {
            switch section {
            case 0:
                return recentSearches.count
            case 1:
                return fileTypeRows.count
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

    // MARK: - Collection view delegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isDisplayingSearchResults {
            super.collectionView(collectionView, didSelectItemAt: indexPath)
        } else {
            switch indexPath.section {
            case 0:
                currentSearchText = recentSearches[indexPath.row]
                searchController.searchBar.text = currentSearchText
            case 1:
                selectedFileType = fileTypeRows[indexPath.row]
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

    override func removeFileTypeButtonPressed() {
        selectedFileType = nil
    }

}

// MARK: - Search results updating

extension SearchViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        currentSearchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces)
    }

}
