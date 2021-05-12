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
import QuickLook
import FloatingPanel
import RealmSwift
import DifferenceKit
import kDriveCore
import CocoaLumberjackSwift

class FileListCollectionViewController: UIViewController, UICollectionViewDataSource, SwipeActionCollectionViewDelegate, SwipeActionCollectionViewDataSource, FileCellDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    private var collectionViewLayout: UICollectionViewFlowLayout!
    let leftRightInset: CGFloat = 12
    private let gridInnerSpacing: CGFloat = 16
    private let maxActivitiesBeforeReload = 100

    private var floatingPanelViewController: DriveFloatingPanelController!
    #if !ISEXTENSION
        private var fileInformationsViewController: FileQuickActionsFloatingPanelViewController!
    #endif

    var headerView: FilesHeaderView?
    var refreshControl: UIRefreshControl!
    private var isLoading = false
    private var initialAppearance = true

    var driveFileManager: DriveFileManager!
    var currentDirectory: File!
    var realFiles = [File]()
    var currentPage = 0
    var sortType: SortType! {
        didSet {
            if sortType != nil {
                headerView?.sortButton.setTitle(sortType.value.translation, for: .normal)
            }
        }
    }
    var sortedChildren = [File]()
    var selectedItems = [File]()
    var uploadingFilesCount: Int = 0
    var listStyle = FileListOptions.instance.currentStyle {
        didSet {
            headerView?.listOrGridButton.setImage(listStyle.icon, for: .normal)
        }
    }

    var normalFolderHierarchy: Bool {
        return true
    }
    /// Override this variable to enabled or disable upload status displayed in the header (enabled by default)
    var showUploadingFiles: Bool {
        return true
    }
    /// Override this variable to enabled or disable multiple selection (enabled by default)
    var isMultipleSelectionEnabled: Bool {
        return true
    }
    var selectionMode = false {
        didSet {
            toggleMultipleSelection()
        }
    }
    var trashSort: Bool {
        #if ISEXTENSION
            return false
        #else
            return self is TrashCollectionViewController && currentDirectory.id == DriveFileManager.trashRootFile.id
        #endif
    }
    var rightBarButtonItems: [UIBarButtonItem]?
    var fromActivities = false
    #if !ISEXTENSION
        lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)
    #endif
    private var needsContentUpdate = false
    private var selectedFile: File!

    private lazy var selectAllBarButtonItem = UIBarButtonItem(title: KDriveStrings.Localizable.buttonSelectAll, style: .plain, target: self, action: #selector(selectAllChildren))
    private var loadingBarButtonItem: UIBarButtonItem = {
        let activityView = UIActivityIndicatorView(style: .gray)
        activityView.startAnimating()
        return UIBarButtonItem(customView: activityView)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        if driveFileManager == nil {
            driveFileManager = AccountManager.instance.currentDriveFileManager
        }
        if currentDirectory == nil {
            currentDirectory = driveFileManager.getRootFile()
        }

        if sortType == nil {
            sortType = UserDefaults.shared.sortType
        }

        navigationController?.setInfomaniakAppearanceNavigationBar()

        navigationItem.title = currentDirectory.name
        navigationItem.backButtonTitle = ""
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.register(UINib(nibName: "FilesHeaderView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "FilesHeaderView")
        addRefreshControl()
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)
        collectionViewLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        collectionViewLayout?.sectionHeadersPinToVisibleBounds = true
        (collectionView as? SwipableCollectionView)?.swipeDataSource = self
        (collectionView as? SwipableCollectionView)?.swipeDelegate = self

        if isMultipleSelectionEnabled {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            collectionView.addGestureRecognizer(longPressGesture)
            rightBarButtonItems = navigationItem.rightBarButtonItems
        }

        if showUploadingFiles {
            observeUploadQueue()
        }
        observeFileUpdated()
        observeNetworkChange()
        observeOptions()

        fetchNextPage()
    }

    func addRefreshControl() {
        refreshControl = UIRefreshControl(frame: CGRect(x: 0, y: 0, width: 128, height: 128))
        refreshControl.addTarget(self, action: #selector(FileListCollectionViewController.forceRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    @IBAction func searchButtonPressed(_ sender: Any) {
        present(SearchFileViewController.instantiateInNavigationController(), animated: true)
    }

    func observeNetworkChange() {
        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] (status) in
            if status == .offline {
                headerView?.offlineView.isHidden = false
            } else {
                headerView?.offlineView.isHidden = true
            }
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
        }
    }

    func observeUploadQueue() {
        uploadingFilesCount = UploadQueue.instance.getUploadingFiles(withParent: currentDirectory.id).count
        UploadQueue.instance.observeUploadCountInParent(self, parentId: currentDirectory.id) { _, count in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                if self.isViewLoaded {
                    let shouldHideUploadCard: Bool
                    if count > 0 {
                        self.headerView?.uploadCardView.detailsLabel.text = KDriveStrings.Localizable.uploadInProgressNumberFile(count)
                        shouldHideUploadCard = false
                    } else {
                        shouldHideUploadCard = true
                    }
                    //only perform reload if needed
                    if shouldHideUploadCard != self.headerView?.uploadCardView.isHidden {
                        self.headerView?.uploadCardView.isHidden = shouldHideUploadCard
                        self.collectionView.performBatchUpdates(nil)
                    }
                }
            }
        }
    }

    func observeFileUpdated() {
        driveFileManager.observeFileUpdated(self, fileId: nil) { [unowned self] file in
            if file.id == self.currentDirectory.id {
                refreshDataSource(withActivities: true)
            } else if let index = sortedChildren.firstIndex(where: { $0.id == file.id }) {
                let oldFile = sortedChildren[index]
                sortedChildren[index] = file
                sortedChildren.last?.isLastInCollection = true
                sortedChildren.first?.isFirstInCollection = true

                //We don't need to call reload data if only the children were updated
                if oldFile.isContentEqual(to: file) {
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    self?.collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
                }
            }
        }
    }

    func observeOptions() {
        FileListOptions.instance.observeListStyleChange(self) { [unowned self] (newStyle) in
            self.listStyle = newStyle
            self.collectionView.reloadData()
        }

        FileListOptions.instance.observeSortTypeChange(self) { [unowned self] (newSortType) in
            self.sortType = newSortType
            self.collectionView.reloadData()
        }
    }

    @objc func forceRefresh() {
        currentPage = 0
        fetchNextPage(forceRefresh: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        #if !ISEXTENSION
            if let centerButton = (tabBarController as? MainTabViewController)?.tabBar.centerButton {
                centerButton.isEnabled = currentDirectory.rights?.createNewFile.value ?? true
            }
        #endif

        if needsContentUpdate {
            needsContentUpdate = false
            collectionView.reloadData()
            fetchNextPage()
        } else if !initialAppearance {
            if let currentDirectory = currentDirectory,
                currentDirectory.fullyDownloaded {
                getFileActivities(directory: currentDirectory)
            }
        }
        initialAppearance = false
    }

    private func refreshDataSource(withActivities: Bool) {
        currentDirectory?.realm?.refresh()
        let parentId = currentDirectory.isRoot ? DriveFileManager.constants.rootID : currentDirectory.id
        driveFileManager.getFile(id: parentId, page: 1, sortType: sortType, forceRefresh: false) { [self] (directory, children, _) in
            if let updatedDirectory = directory, let updatedChildren = children {
                currentDirectory = updatedDirectory.isFrozen ? updatedDirectory : updatedDirectory.freeze()

                updatedChildren.first?.isFirstInCollection = true
                updatedChildren.last?.isLastInCollection = true
                showEmptyView(.emptyFolder, children: updatedChildren)

                var changeset: StagedChangeset<[File]>!
                DispatchQueue.global(qos: .userInteractive).sync {
                    changeset = getChangesetFor(newChildren: updatedChildren)
                }
                collectionView.reload(using: changeset, interrupt: { $0.changeCount > maxActivitiesBeforeReload }) { newChildren in
                    sortedChildren = newChildren
                    updateSelectedItems(newChildren: newChildren)
                }

                setSelectedCells()


                if withActivities {
                    if let currentDirectory = currentDirectory,
                        currentDirectory.fullyDownloaded {
                        getFileActivities(directory: currentDirectory)
                    }
                }
            }
        }
    }

    func fetchNextPage(forceRefresh: Bool = false) {
        currentPage += 1

        isLoading = currentPage == 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isLoading && !self.refreshControl.isRefreshing {
                self.collectionView.refreshControl?.beginRefreshing()
                let offsetPoint = CGPoint(x: 0, y: self.collectionView.contentOffset.y - self.refreshControl.frame.size.height)
                self.collectionView.setContentOffset(offsetPoint, animated: true)
            }
        }

        let parentId = currentDirectory.isRoot ? 1 : currentDirectory.id
        driveFileManager.getFile(id: parentId, page: currentPage, sortType: sortType, forceRefresh: forceRefresh) { [self] (file, children, error) in
            isLoading = false
            refreshControl.endRefreshing()
            if let fetchedCurrentDirectory = file,
                let fetchedChildren = children {
                currentDirectory = fetchedCurrentDirectory.isFrozen ? fetchedCurrentDirectory : fetchedCurrentDirectory.freeze()

                fetchedChildren.first?.isFirstInCollection = true
                fetchedChildren.last?.isLastInCollection = true
                showEmptyView(.emptyFolder, children: fetchedChildren)

                let changeset = getChangesetFor(newChildren: fetchedChildren)

                collectionView.reload(using: changeset) { newChildren in
                    sortedChildren = newChildren
                    updateSelectedItems(newChildren: newChildren)
                }

                setSelectedCells()

                if !fetchedCurrentDirectory.fullyDownloaded && view.window != nil {
                    fetchNextPage()
                } else {
                    getFileActivities(directory: currentDirectory!)
                    // Enable select all button once all pages are fetched
                    /*if selectionMode {
                        navigationItem.rightBarButtonItem = selectAllBarButtonItem
                    }*/
                    // Demo swipe action
                    if !UserDefaults.shared.didDemoSwipe && sortedChildren.count > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let row = min(sortedChildren.count, 2)
                            (collectionView as? SwipableCollectionView)?.simulateSwipe(at: IndexPath(item: row, section: 0))
                        }
                        UserDefaults.shared.didDemoSwipe = true
                    }
                }
            } else {
            }
            if !currentDirectory.fullyDownloaded && sortedChildren.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
                showEmptyView(.noNetwork, children: sortedChildren)
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { (context) in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    func getChangesetFor(newChildren: [File]) -> StagedChangeset<[File]> {
        return StagedChangeset(source: sortedChildren, target: newChildren)
    }

    func getFileActivities(directory: File) {
        driveFileManager.getFolderActivities(file: directory) { [self] (results, _, error) in
            if results != nil {
                refreshDataSource(withActivities: false)
            }
        }
    }

    private func configureUploadHeaderView() {
        headerView?.uploadCardView.titleLabel.text = KDriveStrings.Localizable.uploadInThisFolderTitle
        headerView?.uploadCardView.detailsLabel.text = KDriveStrings.Localizable.uploadInProgressNumberFile(uploadingFilesCount)
        headerView?.uploadCardView.progressView.enableIndeterminate()
    }

    func showEmptyView(_ type: EmptyTableView.EmptyTableViewType, children: [File], showButton: Bool = false) {
        if children.isEmpty {
            let background = EmptyTableView.instantiate(type: type, button: showButton)
            background.actionHandler = { sender in
                self.forceRefresh()
            }
            collectionView.backgroundView = background
            headerView?.sortView.isHidden = true
        } else {
            collectionView.backgroundView = nil
            headerView?.sortView.isHidden = false
        }
    }

    func updateCornersIfNeeded() {
        guard sortedChildren.count > 0 else { return }
        // Get old values
        let firstIndex = 0
        let lastIndex = sortedChildren.count - 1
        let firstWasFirst = sortedChildren[firstIndex].isFirstInCollection
        let lastWasLast = sortedChildren[lastIndex].isLastInCollection
        // Update values
        sortedChildren.first?.isFirstInCollection = true
        sortedChildren.last?.isLastInCollection = true
        // Reload cells if needed
        if !firstWasFirst {
            collectionView.reloadItems(at: [IndexPath(row: firstIndex, section: 0)])
        }
        if !lastWasLast && (firstIndex != lastIndex || firstWasFirst) {
            collectionView.reloadItems(at: [IndexPath(row: lastIndex, section: 0)])
        }
    }

    // MARK: - Multiple selection

    @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        if !selectionMode {
            let pos = sender.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: pos) {
                selectionMode = true
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .init(rawValue: 0))
                selectChild(at: indexPath)
            }
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
        let wasDisabled = selectedItems.count == 0
        selectedItems = sortedChildren
        for index in 0..<selectedItems.count {
            let indexPath = IndexPath(row: index, section: 0)
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredVertically)
        }
        if wasDisabled {
            setSelectionButtonsEnabled(true)
        }
        updateSelectedCount()
    }

    func selectChild(at indexPath: IndexPath) {
        let wasDisabled = selectedItems.count == 0
        selectedItems.append(sortedChildren[indexPath.row])
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
        selectedItems.removeAll()
        setSelectionButtonsEnabled(false)
    }

    private func deselectChild(at indexPath: IndexPath) {
        let selectedFile = sortedChildren[indexPath.row]
        if let index = selectedItems.firstIndex(of: selectedFile) {
            selectedItems.remove(at: index)
        }
        if selectedItems.count == 0 {
            setSelectionButtonsEnabled(false)
        }
        updateSelectedCount()
    }

    /// Update selected items with new objects
    func updateSelectedItems(newChildren: [File]) {
        let selectedFileId = selectedItems.map(\.id)
        selectedItems = newChildren.filter { selectedFileId.contains($0.id) }
    }

    /// Select collection view cells based on `selectedItems`
    func setSelectedCells() {
        if selectionMode && selectedItems.count > 0 {
            for i in 0..<sortedChildren.count where selectedItems.contains(sortedChildren[i]) {
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
        headerView?.selectView.updateTitle(selectedItems.count)
    }

    // MARK: - Collection view data source

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sortedChildren.count
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if headerView == nil {
            headerView = self.collectionView(collectionView, viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionHeader, at: IndexPath(row: 0, section: section)) as? FilesHeaderView
        }
        return headerView!.systemLayoutSizeFitting(CGSize(width: collectionView.frame.width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        headerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "FilesHeaderView", for: indexPath) as? FilesHeaderView
        headerView?.delegate = self
        headerView?.sortButton.setTitle(sortType.value.translation, for: .normal)
        headerView?.listOrGridButton.setImage(listStyle.icon, for: .normal)

        if showUploadingFiles {
            configureUploadHeaderView()
            headerView?.uploadCardView.isHidden = uploadingFilesCount == 0
        }
        return headerView!
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let file = sortedChildren[indexPath.row]
        let cellIdentifier: String
        switch listStyle {
        case .list:
            cellIdentifier = "FileCollectionViewCell"
        case .grid:
            cellIdentifier = "FileGridCollectionViewCell"
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! FileCollectionViewCell
        cell.selectionMode = selectionMode
        cell.initStyle(isFirst: file.isFirstInCollection, isLast: file.isLastInCollection)
        cell.configureWith(file: file)
        cell.delegate = self
        if ReachabilityListener.instance.currentStatus == .offline && !file.isDirectory && !file.isAvailableOffline {
            cell.setEnabled(false)
        } else {
            cell.setEnabled(true)
        }
        if fromActivities {
            cell.moreButton.isHidden = true
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if #available(iOS 13.0, *) {
        } else {
            // Fix for iOS 12
            if let cell = cell as? FileGridCollectionViewCell {
                let file = sortedChildren[indexPath.row]
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
        selectedFile = sortedChildren[indexPath.row]
        if ReachabilityListener.instance.currentStatus == .offline && !selectedFile.isDirectory && !selectedFile.isAvailableOffline {
            return
        }
        #if !ISEXTENSION
            filePresenter.present(driveFileManager: driveFileManager, file: selectedFile, files: sortedChildren, normalFolderHierarchy: normalFolderHierarchy, fromActivities: fromActivities)
        #endif
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if selectionMode {
            deselectChild(at: indexPath)
        }
    }

    func getFileForIndex(index: Int) -> File? {
        if index >= realFiles.count || index < 0 {
            return nil
        }

        return realFiles[index]
    }

    // MARK: - SwipeActionCollectionViewDelegate

    func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath) {
        #if !ISEXTENSION
            let file = sortedChildren[indexPath.row]
            switch action.identifier {
            case UIConstants.swipeActionDeleteIdentifier:
                deleteAction(files: [file])
                break
            case UIConstants.swipeActionMoreIdentifier:
                showQuickActionsPanel(file: file)
                break
            case UIConstants.swipeActionShareIdentifier:
                let shareVC = ShareAndRightsViewController.instantiate()
                shareVC.driveFileManager = driveFileManager
                shareVC.file = sortedChildren[indexPath.row]
                self.navigationController?.pushViewController(shareVC, animated: true)
                break
            default:
                break
            }
        #endif
    }

    #if !ISEXTENSION
        private func showQuickActionsPanel(file: File) {
            if fileInformationsViewController == nil {
                fileInformationsViewController = FileQuickActionsFloatingPanelViewController()
                fileInformationsViewController.presentingParent = self
                fileInformationsViewController.normalFolderHierarchy = normalFolderHierarchy
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

    @discardableResult
    private func deleteAction(files: [File], async: Bool = true) -> Bool? {
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
                        UIConstants.showSnackBarWithAction(message: KDriveStrings.Localizable.snackbarMoveTrashConfirmation(files[0].name), view: self.view, action: KDriveStrings.Localizable.buttonCancel) {
                            if let cancelId = cancelId {
                                self.driveFileManager.cancelAction(file: files[0], cancelId: cancelId) { (error) in
                                    self.getFileActivities(directory: self.currentDirectory)
                                    if error == nil {
                                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.allTrashActionCancelled, view: self.view)
                                    }
                                }
                            }
                        }
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.snackbarMoveTrashConfirmationPlural(files.count), view: self.view)
                    }
                } else {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorMove, view: self.view)
                }
                self.selectionMode = false
                self.getFileActivities(directory: self.currentDirectory)
            }
            return nil
        } else {
            let result = group.wait(timeout: .now() + 5)
            return success && result != .timedOut
        }
    }

    // MARK: - SwipeActionCollectionViewDatasource

    func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        if fromActivities {
            return nil
        }
        switch listStyle {
        case .list:
            var actionsArray = [SwipeCellAction(identifier: "more", title: KDriveStrings.Localizable.buttonMenu, backgroundColor: KDriveAsset.darkBlueColor.color, icon: KDriveAsset.menu.image)]
            if let right = sortedChildren[indexPath.row].rights {
                if right.delete.value ?? false {
                    actionsArray.append(SwipeCellAction(identifier: "delete", title: KDriveStrings.Localizable.buttonDelete, backgroundColor: KDriveAsset.binColor.color, icon: KDriveAsset.delete.image))
                }
                if right.share.value ?? false {
                    actionsArray.insert(SwipeCellAction(identifier: "share", title: KDriveStrings.Localizable.buttonFileRights, backgroundColor: KDriveAsset.infomaniakColor.color, icon: KDriveAsset.share.image), at: 0)
                }
            }
            return actionsArray
        case .grid:
            return nil
        }
    }

    class func instantiate() -> FileListCollectionViewController {
        return UIStoryboard(name: "Files", bundle: nil).instantiateViewController(withIdentifier: "FileListCollectionViewController") as! FileListCollectionViewController
    }

    // MARK: - File cell delegate

    func didTapMoreButton(_ cell: FileCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }

        #if !ISEXTENSION
            showQuickActionsPanel(file: sortedChildren[indexPath.row])
        #endif
    }

}

// MARK: - UICollectionViewDelegateFlowLayout

extension FileListCollectionViewController: UICollectionViewDelegateFlowLayout {

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
}

// MARK: - FilesHeaderViewDelegate
extension FileListCollectionViewController: FilesHeaderViewDelegate, SortOptionsDelegate {

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

    func didClickOnSortingOption(type: SortType) {
        sortType = type
        if !trashSort {
            FileListOptions.instance.currentSortType = sortType
        }
        sortedChildren = [File]()
        collectionView.reloadData()
        currentPage = 0
        fetchNextPage()
    }

    func gridButtonPressed() {
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

        if !fromActivities {
            sortedChildren = [File]()
            currentPage = 0
            fetchNextPage()
        }
    }

    func uploadCardSelected() {
        #if !ISEXTENSION
            let uploadViewController = UploadQueueViewController.instantiate()
            uploadViewController.currentDirectory = currentDirectory
            navigationController?.pushViewController(uploadViewController, animated: true)
        #endif
    }

    @objc func removeFileTypeButtonPressed() { }

    func moveButtonPressed() {
        let selectFolderNavigationViewController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager)
        (selectFolderNavigationViewController.viewControllers.first as? SelectFolderViewController)?.disabledDirectoriesSelection = [selectedItems.first?.parent ?? driveFileManager.getRootFile()]
        (selectFolderNavigationViewController.viewControllers.first as! SelectFolderViewController).selectHandler = { selectedFolder in
            let group = DispatchGroup()
            var success = true
            for file in self.selectedItems {
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
                let message: String
                if success {
                    message = KDriveStrings.Localizable.fileListMoveFileConfirmationSnackbar(self.selectedItems.count, selectedFolder.name)
                } else {
                    message = KDriveStrings.Localizable.errorMove
                }
                UIConstants.showSnackBar(message: message, view: self.view)
                self.selectionMode = false
                self.getFileActivities(directory: self.currentDirectory)
            }
        }
        present(selectFolderNavigationViewController, animated: true)
    }

    @objc func deleteButtonPressed() {
        #if !ISEXTENSION
            let message: NSMutableAttributedString
            if selectedItems.count == 1 {
                message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalMoveTrashDescription(selectedItems[0].name), boldText: selectedItems[0].name)
            } else {
                message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalMoveTrashDescriptionPlural(selectedItems.count))
            }

            let alert = AlertTextViewController(title: KDriveStrings.Localizable.modalMoveTrashTitle, message: message, action: KDriveStrings.Localizable.buttonMove, destructive: true, loading: true) {
                let message: String
                if let success = self.deleteAction(files: self.selectedItems, async: false), success {
                    if self.selectedItems.count == 1 {
                        message = KDriveStrings.Localizable.snackbarMoveTrashConfirmation(self.selectedItems[0].name)
                    } else {
                        message = KDriveStrings.Localizable.snackbarMoveTrashConfirmationPlural(self.selectedItems.count)
                    }
                } else {
                    message = KDriveStrings.Localizable.errorMove
                }
                DispatchQueue.main.async {
                    UIConstants.showSnackBar(message: message, view: self.view)
                    self.selectionMode = false
                    self.getFileActivities(directory: self.currentDirectory)
                }
            }
            present(alert, animated: true)
        #endif
    }

    @objc func menuButtonPressed() {
        #if !ISEXTENSION
            let floatingPanelViewController = DriveFloatingPanelController()
            let selectViewController = SelectFloatingPanelTableViewController()
            floatingPanelViewController.isRemovalInteractionEnabled = true
            selectViewController.files = selectedItems
            floatingPanelViewController.layout = PlusButtonFloatingPanelLayout(height: 200)
            selectViewController.reloadAction = {
                self.selectionMode = false
                self.forceRefresh()
            }

            floatingPanelViewController.set(contentViewController: selectViewController)
            floatingPanelViewController.track(scrollView: selectViewController.tableView)
            self.present(floatingPanelViewController, animated: true)
        #endif
    }
}

#if !ISEXTENSION
// MARK: - SwitchDriveDelegate
    extension FileListCollectionViewController: SwitchDriveDelegate {

        func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
            driveFileManager = newDriveFileManager
            currentDirectory = driveFileManager.getRootFile()
            uploadingFilesCount = UploadQueue.instance.getUploadingFiles(withParent: currentDirectory?.id ?? 1).count
            navigationItem.title = currentDirectory?.name ?? newDriveFileManager.drive.name
            sortedChildren = [File]()
            currentPage = 0
            needsContentUpdate = true
            navigationController?.popToRootViewController(animated: false)
        }
    }
#endif

// MARK: - Top scrollable

extension FileListCollectionViewController: TopScrollable {

    func scrollToTop() {
        if isViewLoaded {
            collectionView.scrollToTop(animated: true, navigationController: navigationController)
        }
    }

}
