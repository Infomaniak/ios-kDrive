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
import CocoaLumberjackSwift
import DifferenceKit

extension SwipeCellAction {
    static let share = SwipeCellAction(identifier: "share", title: KDriveStrings.Localizable.buttonFileRights, backgroundColor: KDriveAsset.infomaniakColor.color, icon: KDriveAsset.share.image)
    static let delete = SwipeCellAction(identifier: "delete", title: KDriveStrings.Localizable.buttonDelete, backgroundColor: KDriveAsset.binColor.color, icon: KDriveAsset.delete.image)
    static let more = SwipeCellAction(identifier: "more", title: KDriveStrings.Localizable.buttonMenu, backgroundColor: KDriveAsset.darkBlueColor.color, icon: KDriveAsset.menu.image)
}

class FileListViewController: UIViewController, UICollectionViewDataSource, SwipeActionCollectionViewDelegate, SwipeActionCollectionViewDataSource {

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
    var uploadingFilesCount = 0
    var nextPage = 1
    var isLoading = false
    var listStyle = FileListOptions.instance.currentStyle {
        didSet {
            headerView?.listOrGridButton.setImage(listStyle.icon, for: .normal)
        }
    }
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
    #if !ISEXTENSION
        lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)
    #endif

    var trashSort: Bool {
        #if ISEXTENSION
            return false
        #else
            return self is TrashCollectionViewController && currentDirectory.id == DriveFileManager.trashRootFile.id
        #endif
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up collection view
        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)
        (collectionView as? SwipableCollectionView)?.swipeDataSource = self
        (collectionView as? SwipableCollectionView)?.swipeDelegate = self
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.register(UINib(nibName: headerViewIdentifier, bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerViewIdentifier)
        collectionViewLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        collectionViewLayout?.sectionHeadersPinToVisibleBounds = true

        // Set up current directory
        if currentDirectory == nil {
            currentDirectory = driveFileManager.getRootFile()
        }
        if configuration.showUploadingFiles {
            uploadingFilesCount = UploadQueue.instance.getUploadingFiles(withParent: currentDirectory.id).count
        }
        navigationItem.title = currentDirectory.id <= DriveFileManager.constants.rootID ? configuration.rootTitle : currentDirectory.name
        navigationItem.backButtonTitle = ""

        // Set up multiple selection gesture
        if configuration.isMultipleSelectionEnabled {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            collectionView.addGestureRecognizer(longPressGesture)
            rightBarButtonItems = navigationItem.rightBarButtonItems
        }

        // First load
        forceRefresh()

        // Set up observers
        setUpObservers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()
    }

    @objc func forceRefresh() {
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

                // Add items to collection view
                let changeset = StagedChangeset(source: sortedFiles, target: fetchedChildren)
                collectionView.reload(using: changeset, interrupt: { $0.changeCount > maxDiffChanges }) { newChildren in
                    sortedFiles = newChildren
                    updateSelectedItems(newChildren: newChildren)
                    showEmptyView()
                }
                setSelectedCells()

                if !fetchedCurrentDirectory.fullyDownloaded && view.window != nil {
                    // Fetch next page
                    nextPage += 1
                    fetchNextPage()
                } else {
                    // Get activities
                    getFileActivities()
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

    func setUpObservers() {
        // Upload files observer
        if configuration.showUploadingFiles {
            UploadQueue.instance.observeUploadCountInParent(self, parentId: currentDirectory.id) { [unowned self] _, count in
                self.uploadingFilesCount = count
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.isViewLoaded else { return }

                    let shouldHideUploadCard: Bool
                    if count > 0 {
                        self.headerView?.uploadCardView.setUploadCount(count)
                        shouldHideUploadCard = false
                    } else {
                        shouldHideUploadCard = true
                    }
                    // Only perform reload if needed
                    if shouldHideUploadCard != self.headerView?.uploadCardView.isHidden {
                        self.headerView?.uploadCardView.isHidden = shouldHideUploadCard
                        self.collectionView.performBatchUpdates(nil)
                    }
                }
            }
        }
        // File observer
        driveFileManager.observeFileUpdated(self, fileId: nil) { [unowned self] file in
            if file.id == self.currentDirectory.id {
                //refreshDataSource(withActivities: true)
            } else if let index = sortedFiles.firstIndex(where: { $0.id == file.id }) {
                let oldFile = sortedFiles[index]
                sortedFiles[index] = file

                // We don't need to call reload data if only the children were updated
                if oldFile.isContentEqual(to: file) {
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    self?.collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
                }
            }
        }
        // Network observer
        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] (status) in
            // Observer is called on main queue
            headerView?.offlineView.isHidden = status != .offline
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
        }
        // List style observer
        FileListOptions.instance.observeListStyleChange(self) { [unowned self] (newStyle) in
            self.listStyle = newStyle
            DispatchQueue.main.async { [weak self] in
                self?.collectionView.reloadData()
            }
        }
        // Sort type observer
        FileListOptions.instance.observeSortTypeChange(self) { [unowned self] (newSortType) in
            self.sortType = newSortType
            DispatchQueue.main.async { [weak self] in
                self?.collectionView.reloadData()
            }
        }
    }

    private func getFileActivities() {
        // TODO
    }

    @discardableResult
    private func deleteFiles(_ files: [File], async: Bool = true) -> Bool? {
        let group = DispatchGroup()
        var success = true
        var cancelId: String?
        for file in files {
            group.enter()
            driveFileManager.deleteFile(file: file) { response, error in
                cancelId = response?.id
                if let error = error {
                    success = false
                    DDLogError("Error while deleting file: \(error)")
                }
                group.leave()
            }
        }
        if async {
            group.notify(queue: DispatchQueue.main) {
                if success {
                    if files.count == 1 {
                        UIConstants.showSnackBarWithAction(message: KDriveStrings.Localizable.snackbarMoveTrashConfirmation(files[0].name), action: KDriveStrings.Localizable.buttonCancel) {
                            guard let cancelId = cancelId else { return }
                            self.driveFileManager.cancelAction(file: files[0], cancelId: cancelId) { (error) in
                                self.getFileActivities()
                                if error == nil {
                                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.allTrashActionCancelled)
                                }
                            }
                        }
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.snackbarMoveTrashConfirmationPlural(files.count))
                    }
                } else {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorMove)
                }
                self.selectionMode = false
                self.getFileActivities()
            }
            return nil
        } else {
            let result = group.wait(timeout: .now() + 5)
            return success && result != .timedOut
        }
    }

    #if !ISEXTENSION
        private func showQuickActionsPanel(file: File) {
            if fileInformationsViewController == nil {
                fileInformationsViewController = FileQuickActionsFloatingPanelViewController()
                fileInformationsViewController.presentingParent = self
                fileInformationsViewController.normalFolderHierarchy = configuration.normalFolderHierarchy
                floatingPanelViewController = DriveFloatingPanelController()
                floatingPanelViewController.isRemovalInteractionEnabled = true
                floatingPanelViewController.layout = FileFloatingPanelLayout(initialState: .half, hideTip: true, backdropAlpha: 0.2)
                floatingPanelViewController.set(contentViewController: fileInformationsViewController)
                floatingPanelViewController.track(scrollView: fileInformationsViewController.tableView)
            }
            fileInformationsViewController.setFile(file, driveFileManager: driveFileManager)
            present(floatingPanelViewController, animated: true)
        }
    #endif

    func showEmptyView(type: EmptyTableView.EmptyTableViewType? = nil) {
        let type = type ?? configuration.emptyViewType
        if sortedFiles.isEmpty {
            let background = EmptyTableView.instantiate(type: type, button: false)
            background.actionHandler = { _ in
                self.forceRefresh()
            }
            collectionView.backgroundView = background
        } else {
            collectionView.backgroundView = nil
        }
        if let headerView = headerView {
            setUpHeaderView(headerView, isListEmpty: sortedFiles.isEmpty)
        }
    }

    /// Override this method to setup the collection view header
    func setUpHeaderView(_ headerView: FilesHeaderView, isListEmpty: Bool) {
        headerView.delegate = self

        headerView.sortView.isHidden = isListEmpty

        headerView.sortButton.setTitle(sortType.value.translation, for: .normal)
        headerView.listOrGridButton.setImage(listStyle.icon, for: .normal)

        if configuration.showUploadingFiles {
            headerView.uploadCardView.isHidden = uploadingFilesCount == 0
            headerView.uploadCardView.titleLabel.text = KDriveStrings.Localizable.uploadInThisFolderTitle
            headerView.uploadCardView.setUploadCount(uploadingFilesCount)
            headerView.uploadCardView.progressView.enableIndeterminate()
        }
    }

    class func instantiate() -> FileListViewController {
        return UIStoryboard(name: "Files", bundle: nil).instantiateViewController(withIdentifier: "FileListCollectionViewController") as! FileListViewController
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
        selectedFiles.append(sortedFiles[indexPath.row])
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
        cell.configureWith(file: file, selectionMode: selectionMode)
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

    // MARK: - Collection view delegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if selectionMode {
            selectChild(at: indexPath)
            return
        }
        let file = sortedFiles[indexPath.row]
        if ReachabilityListener.instance.currentStatus == .offline && !file.isDirectory && !file.isAvailableOffline {
            return
        }
        #if !ISEXTENSION
            filePresenter.present(driveFileManager: driveFileManager, file: file, files: sortedFiles, normalFolderHierarchy: configuration.normalFolderHierarchy, fromActivities: configuration.fromActivities)
        #endif
    }

    // MARK: - Swipe action collection view delegate

    func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath) {
        #if !ISEXTENSION
            let file = sortedFiles[indexPath.row]
            switch action {
            case .share:
                let shareVC = ShareAndRightsViewController.instantiate()
                shareVC.file = file
                navigationController?.pushViewController(shareVC, animated: true)
            case .more:
                showQuickActionsPanel(file: file)
            case .delete:
                deleteFiles([file])
            default:
                break
            }
        #endif
    }

    // MARK: - Swipe action collection view data source

    func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        if configuration.fromActivities || listStyle == .grid {
            return nil
        }
        var actions = [SwipeCellAction]()
        let right = sortedFiles[indexPath.row].rights
        if right?.share.value ?? false {
            actions.append(.share)
        }
        actions.append(.more)
        if right?.delete.value ?? false {
            actions.append(.delete)
        }
        return actions
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

// MARK: - File grid cell delegate

extension FileListViewController: FileGridCellDelegate {

    func didTapMoreButton(_ cell: FileCollectionViewCell) {
        #if !ISEXTENSION
            guard let indexPath = collectionView.indexPath(for: cell) else {
                return
            }
            showQuickActionsPanel(file: sortedFiles[indexPath.row])
        #endif
    }

}

// MARK: - Files header view delegate

extension FileListViewController: FilesHeaderViewDelegate {

    func filterButtonPressed() {
        let floatingPanelViewController = DriveFloatingPanelController()
        let sortOptionsViewController = FloatingPanelSortOptionTableViewController()

        sortOptionsViewController.sortType = sortType
        sortOptionsViewController.trashSort = trashSort
        sortOptionsViewController.delegate = self

        floatingPanelViewController.isRemovalInteractionEnabled = true
        floatingPanelViewController.delegate = sortOptionsViewController

        floatingPanelViewController.set(contentViewController: sortOptionsViewController)
        floatingPanelViewController.track(scrollView: sortOptionsViewController.tableView)
        present(floatingPanelViewController, animated: true)
    }

    func gridButtonPressed() {
        // Toggle grid/list
        if listStyle == .grid {
            listStyle = .list
        } else {
            listStyle = .grid
        }
        FileListOptions.instance.currentStyle = listStyle

        UIView.transition(with: collectionView, duration: 0.25, options: .transitionCrossDissolve) {
            self.collectionViewLayout.invalidateLayout()
            self.collectionView.reloadData()
        } completion: { _ in }
    }

    #if !ISEXTENSION
        func uploadCardSelected() {
            let uploadViewController = UploadQueueViewController.instantiate()
            uploadViewController.currentDirectory = currentDirectory
            navigationController?.pushViewController(uploadViewController, animated: true)
        }

        func moveButtonPressed() {
            let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager)
            let selectFolderViewController = selectFolderNavigationController.topViewController as? SelectFolderViewController
            selectFolderViewController?.disabledDirectoriesSelection = [selectedFiles.first?.parent ?? driveFileManager.getRootFile()]
            selectFolderViewController?.selectHandler = { selectedFolder in
                let group = DispatchGroup()
                var success = true
                for file in self.selectedFiles {
                    group.enter()
                    self.driveFileManager.moveFile(file: file, newParent: selectedFolder) { (response, _, error) in
                        if let error = error {
                            success = false
                            DDLogError("Error while moving file: \(error)")
                        }
                        group.leave()
                    }
                }
                group.notify(queue: DispatchQueue.main) {
                    let message = success ? KDriveStrings.Localizable.fileListMoveFileConfirmationSnackbar(self.selectedFiles.count, selectedFolder.name) : KDriveStrings.Localizable.errorMove
                    UIConstants.showSnackBar(message: message)
                    self.selectionMode = false
                    self.getFileActivities()
                }
            }
            present(selectFolderNavigationController, animated: true)
        }

        func deleteButtonPressed() {
            let message: NSMutableAttributedString
            if selectedFiles.count == 1 {
                message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalMoveTrashDescription(selectedFiles[0].name), boldText: selectedFiles[0].name)
            } else {
                message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalMoveTrashDescriptionPlural(selectedFiles.count))
            }

            let alert = AlertTextViewController(title: KDriveStrings.Localizable.modalMoveTrashTitle, message: message, action: KDriveStrings.Localizable.buttonMove, destructive: true, loading: true) {
                let message: String
                if let success = self.deleteFiles(self.selectedFiles, async: false), success {
                    if self.selectedFiles.count == 1 {
                        message = KDriveStrings.Localizable.snackbarMoveTrashConfirmation(self.selectedFiles[0].name)
                    } else {
                        message = KDriveStrings.Localizable.snackbarMoveTrashConfirmationPlural(self.selectedFiles.count)
                    }
                } else {
                    message = KDriveStrings.Localizable.errorMove
                }
                DispatchQueue.main.async {
                    UIConstants.showSnackBar(message: message)
                    self.selectionMode = false
                    self.getFileActivities()
                }
            }
            present(alert, animated: true)
        }

        func menuButtonPressed() {
            let floatingPanelViewController = DriveFloatingPanelController()
            let selectViewController = SelectFloatingPanelTableViewController()
            floatingPanelViewController.isRemovalInteractionEnabled = true
            selectViewController.files = selectedFiles
            floatingPanelViewController.layout = PlusButtonFloatingPanelLayout(height: 200)
            selectViewController.reloadAction = {
                self.selectionMode = false
                self.forceRefresh()
            }
            floatingPanelViewController.set(contentViewController: selectViewController)
            floatingPanelViewController.track(scrollView: selectViewController.tableView)
            self.present(floatingPanelViewController, animated: true)
        }
    #endif

}

// MARK: - Sort options delegate

extension FileListViewController: SortOptionsDelegate {

    func didClickOnSortingOption(type: SortType) {
        sortType = type
        if !trashSort {
            FileListOptions.instance.currentSortType = sortType
        }
        forceRefresh()
    }

}
