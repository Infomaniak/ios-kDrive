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
import DifferenceKit

class FileListViewController: UIViewController, UICollectionViewDataSource, SwipeActionCollectionViewDelegate, SwipeActionCollectionViewDataSource, FileGridCellDelegate {

    // MARK: - Constants

    let leftRightInset: CGFloat = 24
    let gridInnerSpacing: CGFloat = 16
    let maxDiffChanges = 100
    let headerViewIdentifier = "FilesHeaderView"

    // MARK: - Configuration

    struct Configuration {
        /// Is normal folder hierarchy
        var normalFolderHierarchy: Bool = true
        /// Enable or disable upload status displayed in the header (enabled by default)
        var showUploadingFiles: Bool = true
        /// Enable or disable multiple selection (enabled by default)
        var isMultipleSelectionEnabled: Bool = true
        /// Is displayed from activities
        var fromActivities: Bool = false
        /// Root folder title
        var rootTitle: String
        /// Type of empty view to display
        var emptyViewType: EmptyTableView.EmptyTableViewType
    }

    // MARK: - Properties

    @IBOutlet weak var collectionView: UICollectionView!
    var collectionViewLayout: UICollectionViewFlowLayout!
    var refreshControl = UIRefreshControl()
    var headerView: FilesHeaderView?
    var floatingPanelViewController: DriveFloatingPanelController!
    #if !ISEXTENSION
        var fileInformationsViewController: FileQuickActionsFloatingPanelViewController!
    #endif
    var rightBarButtonItems: [UIBarButtonItem]?

    var driveFileManager: DriveFileManager = AccountManager.instance.currentDriveFileManager
    var currentDirectory: File!
    lazy var configuration = Configuration(rootTitle: driveFileManager.drive.name, emptyViewType: .emptyFolder)
    var nextPage = 1
    var isLoading = false
    var listStyle = FileListOptions.instance.currentStyle {
        didSet {
            headerView?.listOrGridButton.setImage(listStyle.icon, for: .normal)
        }
    }
    var files: [File] = []
    var sortType = FileListOptions.instance.currentSortType {
        didSet {
            headerView?.sortButton.setTitle(sortType.value.translation, for: .normal)
        }
    }
    var sortedFiles: [File] = []
    var selectionMode = false {
        didSet {
            toggleMultipleSelection()
        }
    }
    var selectedFiles: [File] = []
    /*#if !ISEXTENSION
        lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)
    #endif*/

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up collection view
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.register(UINib(nibName: headerViewIdentifier, bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerViewIdentifier)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        // Set up current directory
        if currentDirectory == nil {
            currentDirectory = driveFileManager.getRootFile()
        }
        if currentDirectory.id <= DriveFileManager.constants.rootID {
            navigationItem.title = configuration.rootTitle
        } else {
            navigationItem.title = currentDirectory.name
        }

        // Set up multiple selection gesture
        if configuration.isMultipleSelectionEnabled {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            collectionView.addGestureRecognizer(longPressGesture)
            rightBarButtonItems = navigationItem.rightBarButtonItems
        }

        // First load
        refreshData()

        // Set up observers
    }

    deinit {
        // Cancel observers
    }

    @objc func refreshData() {
        nextPage = 1
        fetchNextPage()
    }

    func fetchNextPage(forceRefresh: Bool = false) {
        // Show refresh control if loading is slow
        isLoading = nextPage == 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isLoading && !self.refreshControl.isRefreshing {
                self.collectionView.refreshControl?.beginRefreshing()
                let offsetPoint = CGPoint(x: 0, y: self.collectionView.contentOffset.y - self.refreshControl.frame.size.height)
                self.collectionView.setContentOffset(offsetPoint, animated: true)
            }
        }

        driveFileManager.getFile(id: currentDirectory.id, page: nextPage, sortType: sortType, forceRefresh: forceRefresh) { [self] (file, children, error) in
            isLoading = false
            refreshControl.endRefreshing()
            if let fetchedCurrentDirectory = file,
                let fetchedChildren = children {
                currentDirectory = fetchedCurrentDirectory.isFrozen ? fetchedCurrentDirectory : fetchedCurrentDirectory.freeze()

                showEmptyView()

                // Add items to collection view
                let changeset = StagedChangeset(source: sortedFiles, target: fetchedChildren)
                collectionView.reload(using: changeset, interrupt: { $0.changeCount > maxDiffChanges }) { newChildren in
                    sortedFiles = newChildren
                    updateSelectedItems(newChildren: newChildren)
                }
                setSelectedCells()

                if !fetchedCurrentDirectory.fullyDownloaded && view.window != nil {
                    // Fetch next page
                    nextPage += 1
                    fetchNextPage()
                } else {
                    // Get activities
                    //getFileActivities(directory: currentDirectory)
                    // Demo swipe action
                    if !UserDefaults.shared.didDemoSwipe && sortedFiles.count > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let row = min(sortedFiles.count, 2)
                            (collectionView as? SwipableCollectionView)?.simulateSwipe(at: IndexPath(item: row, section: 0))
                        }
                        UserDefaults.shared.didDemoSwipe = true
                    }
                }
            }
            // No network
            if !currentDirectory.fullyDownloaded && sortedFiles.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
                showEmptyView(type: .noNetwork)
            }
        }
    }

    func showEmptyView(type: EmptyTableView.EmptyTableViewType? = nil) {
        let type = type ?? configuration.emptyViewType
        if sortedFiles.isEmpty {
            let background = EmptyTableView.instantiate(type: type, button: false)
            background.actionHandler = { _ in
                self.refreshData()
            }
            collectionView.backgroundView = background
            if let headerView = headerView {
                setUpHeaderView(headerView, isListEmpty: true)
            }
        } else {
            collectionView.backgroundView = nil
            if let headerView = headerView {
                setUpHeaderView(headerView, isListEmpty: false)
            }
        }
    }

    func setUpHeaderView(_ headerView: FilesHeaderView, isListEmpty: Bool) {
        //headerView.delegate = self

        headerView.sortView.isHidden = isListEmpty

        headerView.sortButton.setTitle(sortType.value.translation, for: .normal)
        headerView.listOrGridButton.setImage(listStyle.icon, for: .normal)

        if configuration.showUploadingFiles {
            //configureUploadHeaderView()
            //headerView?.uploadCardView.isHidden = uploadingFilesCount == 0
        }
    }

    // MARK: - Multiple selection

    @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        guard !selectionMode else { return }
        let pos = sender.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: pos) {
            selectionMode = true
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .init(rawValue: 0))
            selectChild(at: indexPath)
        }
    }

    func toggleMultipleSelection() {
        if selectionMode {
            navigationItem.title = nil
            headerView?.selectView.isHidden = false
            collectionView.allowsMultipleSelection = true
            navigationController?.navigationBar.prefersLargeTitles = false
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(cancelMultipleSelection))
            navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveStrings.Localizable.buttonClose
            //navigationItem.rightBarButtonItem = currentDirectory.fullyDownloaded ? selectAllBarButtonItem : loadingBarButtonItem
            navigationItem.rightBarButtonItem = nil
            let generator = UIImpactFeedbackGenerator()
            generator.prepare()
            generator.impactOccurred()
        } else {
            deselectAllChildren()
            headerView?.selectView.isHidden = true
            collectionView.allowsMultipleSelection = false
            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.title = currentDirectory.name
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItems = rightBarButtonItems
        }
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
    }

    @objc func cancelMultipleSelection() {
        selectionMode = false
    }

    @objc func selectAllChildren() {
        let wasDisabled = selectedFiles.count == 0
        selectedFiles = sortedFiles
        for index in 0..<selectedFiles.count {
            let indexPath = IndexPath(row: index, section: 0)
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredVertically)
        }
        if wasDisabled {
            setSelectionButtonsEnabled(true)
        }
        updateSelectedCount()
    }

    func selectChild(at indexPath: IndexPath) {
        let wasDisabled = selectedFiles.count == 0
        sortedFiles.append(sortedFiles[indexPath.row])
        if wasDisabled {
            setSelectionButtonsEnabled(true)
        }
        updateSelectedCount()
    }

    private func deselectAllChildren() {
        if let indexPaths = collectionView.indexPathsForSelectedItems {
            for indexPath in indexPaths {
                collectionView.deselectItem(at: indexPath, animated: true)
            }
        }
        selectedFiles.removeAll()
        setSelectionButtonsEnabled(false)
    }

    private func deselectChild(at indexPath: IndexPath) {
        let selectedFile = sortedFiles[indexPath.row]
        if let index = selectedFiles.firstIndex(of: selectedFile) {
            selectedFiles.remove(at: index)
        }
        if selectedFiles.count == 0 {
            setSelectionButtonsEnabled(false)
        }
        updateSelectedCount()
    }

    /// Update selected items with new objects
    func updateSelectedItems(newChildren: [File]) {
        let selectedFileId = selectedFiles.map(\.id)
        selectedFiles = newChildren.filter { selectedFileId.contains($0.id) }
    }

    /// Select collection view cells based on `selectedItems`
    func setSelectedCells() {
        if selectionMode && selectedFiles.count > 0 {
            for i in 0..<sortedFiles.count where selectedFiles.contains(sortedFiles[i]) {
                collectionView.selectItem(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .centeredVertically)
            }
        }
    }

    private func setSelectionButtonsEnabled(_ enabled: Bool) {
        headerView?.selectView.moveButton.isEnabled = enabled
        headerView?.selectView.deleteButton.isEnabled = enabled
        headerView?.selectView.moreButton.isEnabled = enabled
    }

    private func updateSelectedCount() {
        headerView?.selectView.updateTitle(selectedFiles.count)
    }

    // MARK: - Collection view data source

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sortedFiles.count
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerViewIdentifier, for: indexPath) as! FilesHeaderView
        setUpHeaderView(headerView, isListEmpty: sortedFiles.isEmpty)
        self.headerView = headerView
        return headerView
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellType: UICollectionViewCell.Type
        switch listStyle {
        case .list:
            cellType = FileCollectionViewCell.self
        case .grid:
            cellType = FileGridCollectionViewCell.self
        }
        let cell = collectionView.dequeueReusableCell(type: cellType, for: indexPath) as! FileCollectionViewCell

        let file = sortedFiles[indexPath.row]
        cell.initStyle(isFirst: indexPath.row == 0, isLast: indexPath.row == sortedFiles.count - 1)
        cell.configureWith(file: file)
        cell.selectionMode = selectionMode
        (cell as? FileGridCollectionViewCell)?.delegate = self
        if ReachabilityListener.instance.currentStatus == .offline && !file.isDirectory && !file.isAvailableOffline {
            cell.setEnabled(false)
        } else {
            cell.setEnabled(true)
        }
        if configuration.fromActivities {
            (cell as? FileGridCollectionViewCell)?.moreButton.isHidden = true
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if #available(iOS 13.0, *) {
        } else {
            // Fix for iOS 12
            if let cell = cell as? FileGridCollectionViewCell {
                let file = sortedFiles[indexPath.row]
                cell.moreButton.tintColor = file.isDirectory || !file.hasThumbnail ? KDriveAsset.iconColor.color : .white
            }
        }
    }

    // MARK: - Swipe action collection view delegate

    func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath) {
        // TODO
    }

    // MARK: - Swipe action collection view data source

    func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        // TODO
        return nil
    }

    // MARK: - File grid cell delegate

    func didTapMoreButton(_ cell: FileCollectionViewCell) {
        // TODO
    }

}

// MARK: - UICollectionViewDelegateFlowLayout

extension FileListViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        switch listStyle {
        case .list:
            // Important: subtract safe area insets
            let cellWidth = collectionView.bounds.width - collectionView.safeAreaInsets.left - collectionView.safeAreaInsets.right - leftRightInset * 2
            return CGSize(width: cellWidth, height: 60)
        case .grid:
            // Adjust cell size based on screen size
            let totalWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
            let cellWidth = floor((totalWidth - gridInnerSpacing) / 2 - leftRightInset)
            return CGSize(width: min(cellWidth, 174), height: min(floor(cellWidth * 130 / 174), 130))
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        switch listStyle {
        case .list:
            return 0
        case .grid:
            return gridInnerSpacing
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        switch listStyle {
        case .list:
            return 0
        case .grid:
            return gridInnerSpacing
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: leftRightInset, bottom: 0, right: leftRightInset)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if headerView == nil {
            headerView = self.collectionView(collectionView, viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionHeader, at: IndexPath(row: 0, section: section)) as? FilesHeaderView
        }
        return headerView!.systemLayoutSizeFitting(CGSize(width: collectionView.frame.width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    }
}
