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
}

class FileListViewController: UIViewController, UICollectionViewDataSource, SwipeActionCollectionViewDelegate, SwipeActionCollectionViewDataSource {

    class var storyboard: UIStoryboard { Storyboard.files }
    class var storyboardIdentifier: String { "FileListViewController" }

    // MARK: - Constants

    private let leftRightInset: CGFloat = 12
    private let gridInnerSpacing: CGFloat = 16
    private let maxDiffChanges = 100
    private let headerViewIdentifier = "FilesHeaderView"

    // MARK: - Configuration

    struct Configuration {
        /// Is normal folder hierarchy
        var normalFolderHierarchy = true
        /// Enable or disable upload status displayed in the header (enabled by default)
        var showUploadingFiles = true
        /// Enable or disable multiple selection (enabled by default)
        var isMultipleSelectionEnabled = true
        /// Enable or disable refresh control (enabled by default)
        var isRefreshControlEnabled = true
        /// Is displayed from activities
        var fromActivities = false
        /// Root folder title
        var rootTitle: String?
        /// Type of empty view to display
        var emptyViewType: EmptyTableView.EmptyTableViewType
    }

    // MARK: - Properties

    @IBOutlet weak var collectionView: UICollectionView!
    var collectionViewLayout: UICollectionViewFlowLayout!
    var refreshControl = UIRefreshControl()
    private var headerView: FilesHeaderView?
    private var floatingPanelViewController: DriveFloatingPanelController!
    #if !ISEXTENSION
        private var fileInformationsViewController: FileQuickActionsFloatingPanelViewController!
    #endif
    private var rightBarButtonItems: [UIBarButtonItem]?

    var driveFileManager: DriveFileManager!
    var currentDirectory: File! {
        didSet {
            setTitle()
        }
    }
    lazy var configuration = Configuration(emptyViewType: .emptyFolder)
    private var uploadingFilesCount = 0
    private var nextPage = 1
    private var isLoading = false
    private var isContentLoaded = false
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
    var selectedFiles = Set<File>()
    #if !ISEXTENSION
        lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)
    #endif

    private var uploadsObserver: ObservationToken?
    private var filesObserver: ObservationToken?
    private var networkObserver: ObservationToken?
    private var listStyleObserver: ObservationToken?
    private var sortTypeObserver: ObservationToken?

    private var background: EmptyTableView?

    var trashSort: Bool {
        #if ISEXTENSION
            return false
        #else
            return self is TrashViewController && currentDirectory.isRoot
        #endif
    }

    // MARK: - View controller lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setTitle()

        navigationItem.backButtonTitle = ""

        // Set up collection view
        if configuration.isRefreshControlEnabled {
            refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
            collectionView.refreshControl = refreshControl
        }
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
            currentDirectory = driveFileManager?.getRootFile()
        }
        if configuration.showUploadingFiles {
            updateUploadCount()
        }

        // Set up multiple selection gesture
        if configuration.isMultipleSelectionEnabled {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            collectionView.addGestureRecognizer(longPressGesture)
            rightBarButtonItems = navigationItem.rightBarButtonItems
        }

        // First load
        reloadData()

        // Set up observers
        setUpObservers()

        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func appWillEnterForeground() {
        viewWillAppear(true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()

        #if !ISEXTENSION
            (tabBarController as? MainTabViewController)?.tabBar.centerButton?.isEnabled = currentDirectory?.rights?.createNewFile.value ?? true
        #endif

        // Refresh data
        if isContentLoaded && !isLoading && currentDirectory != nil && currentDirectory.fullyDownloaded {
            getNewChanges()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if sortedFiles.isEmpty {
            updateEmptyView()
        }
        coordinator.animate { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    @IBAction func searchButtonPressed(_ sender: Any) {
        present(SearchViewController.instantiateInNavigationController(driveFileManager: driveFileManager), animated: true)
    }

    // MARK: - Overridable methods

    func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        guard driveFileManager != nil && currentDirectory != nil else {
            DispatchQueue.main.async {
                completion(.success([]), false, true)
            }
            return
        }

        driveFileManager.getFile(id: currentDirectory.id, page: page, sortType: sortType, forceRefresh: forceRefresh) { [weak self] file, children, error in
            if let fetchedCurrentDirectory = file, let fetchedChildren = children {
                self?.currentDirectory = fetchedCurrentDirectory.isFrozen ? fetchedCurrentDirectory : fetchedCurrentDirectory.freeze()
                completion(.success(fetchedChildren), !fetchedCurrentDirectory.fullyDownloaded, true)
            } else {
                completion(.failure(error ?? DriveError.localError), false, true)
            }
        }
    }

    func getNewChanges() {
        guard currentDirectory != nil else { return }
        driveFileManager?.getFolderActivities(file: currentDirectory) { [weak self] results, _, error in
            if results != nil {
                self?.reloadData(withActivities: false)
            } else if let error = error as? DriveError, error == DriveError.objectNotFound {
                // Pop view controller
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }

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

    func updateChild(_ file: File, at index: Int) {
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

    // MARK: - Public methods

    final func reloadData(page: Int = 1, forceRefresh: Bool = false, withActivities: Bool = true) {
        if page == 1 && configuration.isRefreshControlEnabled {
            // Show refresh control if loading is slow
            isLoading = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.isLoading && !self.refreshControl.isRefreshing {
                    self.refreshControl.beginRefreshing()
                    let offsetPoint = CGPoint(x: 0, y: self.collectionView.contentOffset.y - self.refreshControl.frame.size.height)
                    self.collectionView.setContentOffset(offsetPoint, animated: true)
                }
            }
        }

        getFiles(page: page, sortType: sortType, forceRefresh: forceRefresh) { [weak self] result, moreComing, replaceFiles in
            guard let self = self else { return }
            self.isLoading = false
            if self.configuration.isRefreshControlEnabled {
                self.refreshControl.endRefreshing()
            }
            switch result {
            case .success(let newFiles):
                let files: [File]
                if replaceFiles || page == 1 {
                    files = newFiles
                } else {
                    files = self.sortedFiles + newFiles
                }

                self.showEmptyViewIfNeeded(files: files)
                self.reloadCollectionView(with: files)

                if moreComing {
                    self.reloadData(page: page + 1, forceRefresh: forceRefresh)
                } else {
                    self.isContentLoaded = true
                    if withActivities {
                        self.getNewChanges()
                    }
                }
            case .failure(let error):
                if let error = error as? DriveError, error == DriveError.objectNotFound {
                    // Pop view controller
                    self.navigationController?.popViewController(animated: true)
                }
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
        }
    }

    @objc func forceRefresh() {
        reloadData(forceRefresh: true, withActivities: false)
    }

    final func setUpObservers() {
        // Upload files observer
        observeUploads()
        // File observer
        observeFiles()
        // Network observer
        observeNetwork()
        // Options observer
        observeListOptions()
    }

    final func observeUploads() {
        guard configuration.showUploadingFiles && currentDirectory != nil && uploadsObserver == nil else { return }

        uploadsObserver = UploadQueue.instance.observeUploadCountInParent(self, parentId: currentDirectory.id) { [unowned self] _, uploadCount in
            self.uploadingFilesCount = uploadCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isViewLoaded else { return }

                let shouldHideUploadCard: Bool
                if uploadCount > 0 {
                    self.headerView?.uploadCardView.setUploadCount(uploadCount)
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

    final func observeFiles() {
        guard filesObserver == nil else { return }
        filesObserver = driveFileManager?.observeFileUpdated(self, fileId: nil) { [unowned self] file in
            if file.id == self.currentDirectory?.id {
                reloadData()
            } else if let index = sortedFiles.firstIndex(where: { $0.id == file.id }) {
                updateChild(file, at: index)
            }
        }
    }

    final func observeNetwork() {
        guard networkObserver == nil else { return }
        networkObserver = ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] status in
            // Observer is called on main queue
            headerView?.offlineView.isHidden = status != .offline
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
        }
    }

    final func observeListOptions() {
        guard listStyleObserver == nil && sortTypeObserver == nil else { return }
        // List style observer
        listStyleObserver = FileListOptions.instance.observeListStyleChange(self) { [unowned self] newStyle in
            self.listStyle = newStyle
            DispatchQueue.main.async { [weak self] in
                UIView.transition(with: collectionView, duration: 0.25, options: .transitionCrossDissolve) {
                    self?.collectionViewLayout.invalidateLayout()
                    self?.collectionView.reloadData()
                    self?.setSelectedCells()
                }
            }
        }
        // Sort type observer
        sortTypeObserver = FileListOptions.instance.observeSortTypeChange(self) { [unowned self] newSortType in
            self.sortType = newSortType
            reloadData()
        }
    }

    final func updateUploadCount() {
        guard currentDirectory != nil else { return }
        uploadingFilesCount = UploadQueue.instance.getUploadingFiles(withParent: currentDirectory.id).count
    }

    final func showEmptyViewIfNeeded(type: EmptyTableView.EmptyTableViewType? = nil, files: [File]) {
        let type = type ?? configuration.emptyViewType
        if files.isEmpty {
            background = EmptyTableView.instantiate(type: type, button: false)
            updateEmptyView()
            background?.actionHandler = { _ in
                self.forceRefresh()
            }
            collectionView.backgroundView = background
        } else {
            collectionView.backgroundView = nil
        }
        if let headerView = headerView {
            setUpHeaderView(headerView, isListEmpty: files.isEmpty)
        }
    }

    final func removeFileFromList(id: Int) {
        let newSortedFiles = sortedFiles.filter { $0.id != id }
        reloadCollectionView(with: newSortedFiles)
        showEmptyViewIfNeeded(files: newSortedFiles)
    }

    static func instantiate(driveFileManager: DriveFileManager) -> Self {
        let viewController = storyboard.instantiateViewController(withIdentifier: storyboardIdentifier) as! Self
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    // MARK: - Private methods

    private func setTitle() {
        if currentDirectory?.isRoot ?? false {
            if let rootTitle = configuration.rootTitle {
                navigationItem.title = rootTitle
            } else {
                navigationItem.title = driveFileManager?.drive.name ?? ""
            }
        } else {
            navigationItem.title = currentDirectory?.name ?? ""
        }
    }

    private func updateEmptyView() {
        if let emptyBackground = background {
            if UIDevice.current.orientation.isPortrait {
                emptyBackground.emptyImageFrameViewHeightConstant.constant = 200
            }
            if UIDevice.current.orientation.isLandscape {
                emptyBackground.emptyImageFrameViewHeightConstant.constant = 120
            }
            emptyBackground.emptyImageFrameView.cornerRadius = emptyBackground.emptyImageFrameViewHeightConstant.constant / 2
        }
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
                            self.driveFileManager.cancelAction(file: files[0], cancelId: cancelId) { error in
                                self.getNewChanges()
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
                if self.selectionMode {
                    self.selectionMode = false
                }
                self.getNewChanges()
            }
            return nil
        } else {
            let result = group.wait(timeout: .now() + 5)
            return success && result != .timedOut
        }
    }

    private func reloadCollectionView(with files: [File]) {
        let firstFileId = sortedFiles.first?.id
        let lastFileId = sortedFiles.last?.id
        // Reload file list with DifferenceKit
        let changeSet = StagedChangeset(source: sortedFiles, target: files)
        collectionView.reload(using: changeSet) { $0.changeCount > self.maxDiffChanges } setData: { files in
            sortedFiles = files
            updateSelectedItems(newChildren: files)
        }
        // Reload corners
        if listStyle == .list,
            let oldFirstFileId = firstFileId,
            let oldLastFileId = lastFileId,
            let newFirstFileId = sortedFiles.first?.id,
            let newLastFileId = sortedFiles.last?.id {
            var indexPaths = [IndexPath]()
            if oldFirstFileId != newFirstFileId {
                indexPaths.append(IndexPath(item: 0, section: 0))
                if let index = sortedFiles.firstIndex(where: { $0.id == oldFirstFileId }) {
                    indexPaths.append(IndexPath(item: index, section: 0))
                }
            }
            if oldLastFileId != newLastFileId {
                indexPaths.append(IndexPath(item: sortedFiles.count - 1, section: 0))
                if let index = sortedFiles.firstIndex(where: { $0.id == oldLastFileId }) {
                    indexPaths.append(IndexPath(item: index, section: 0))
                }
            }
            if !indexPaths.isEmpty {
                collectionView.reloadItems(at: indexPaths)
            }
        }
        setSelectedCells()
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

    final func toggleMultipleSelection() {
        if selectionMode {
            navigationItem.title = nil
            headerView?.selectView.isHidden = false
            collectionView.allowsMultipleSelection = true
            navigationController?.navigationBar.prefersLargeTitles = false
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(cancelMultipleSelection))
            navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveStrings.Localizable.buttonClose
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

    @objc final func cancelMultipleSelection() {
        selectionMode = false
    }

    @objc final func selectAllChildren() {
        let wasDisabled = selectedFiles.isEmpty
        selectedFiles = Set(sortedFiles)
        for index in 0..<selectedFiles.count {
            let indexPath = IndexPath(row: index, section: 0)
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredVertically)
        }
        if wasDisabled {
            setSelectionButtonsEnabled(true)
        }
        updateSelectedCount()
    }

    final func selectChild(at indexPath: IndexPath) {
        let wasDisabled = selectedFiles.isEmpty
        selectedFiles.insert(sortedFiles[indexPath.row])
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
        if selectedFiles.isEmpty {
            setSelectionButtonsEnabled(false)
        }
        updateSelectedCount()
    }

    /// Update selected items with new objects
    final func updateSelectedItems(newChildren: [File]) {
        let selectedFileId = selectedFiles.map(\.id)
        selectedFiles = Set(newChildren.filter { selectedFileId.contains($0.id) })
    }

    /// Select collection view cells based on `selectedItems`
    final func setSelectedCells() {
        if selectionMode && !selectedFiles.isEmpty {
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
        cell.delegate = self
        if ReachabilityListener.instance.currentStatus == .offline && !file.isDirectory && !file.isAvailableOffline {
            cell.setEnabled(false)
        } else {
            cell.setEnabled(true)
        }
        if configuration.fromActivities {
            cell.moreButton.isHidden = true
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

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if selectionMode {
            deselectChild(at: indexPath)
        }
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
        let rights = sortedFiles[indexPath.row].rights
        if rights?.share.value ?? false {
            actions.append(.share)
        }
        if rights?.delete.value ?? false {
            actions.append(.delete)
        }
        return actions
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveID")
        if let currentDirectory = currentDirectory {
            coder.encode(currentDirectory.id, forKey: "DirectoryID")
        }
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveID")
        let directoryId = coder.decodeInteger(forKey: "DirectoryID")

        // Drive File Manager should be consistent
        let maybeDriveFileManager: DriveFileManager?
        #if ISEXTENSION
        maybeDriveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId)
        #else
        if !(self is SharedWithMeViewController) {
            maybeDriveFileManager = (tabBarController as? MainTabViewController)?.driveFileManager
        } else {
            maybeDriveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId)
        }
        #endif
        guard let driveFileManager = maybeDriveFileManager else {
            // Handle error?
            return
        }
        self.driveFileManager = driveFileManager
        currentDirectory = driveFileManager.getCachedFile(id: directoryId)
        if currentDirectory == nil && directoryId > DriveFileManager.constants.rootID {
            navigationController?.popViewController(animated: true)
        }
        setTitle()
        observeUploads()
        observeFiles()
        reloadData()
    }

}

// MARK: - Collection view delegate flow layout

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

// MARK: - File cell delegate

extension FileListViewController: FileCellDelegate {

    @objc func didTapMoreButton(_ cell: FileCollectionViewCell) {
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

    func sortButtonPressed() {
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
        // Collection view will be reloaded via the observer
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
                    self.driveFileManager.moveFile(file: file, newParent: selectedFolder) { _, _, error in
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
                    self.getNewChanges()
                }
            }
            present(selectFolderNavigationController, animated: true)
        }

        @objc func deleteButtonPressed() {
            let message: NSMutableAttributedString
            if selectedFiles.count == 1 {
                message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalMoveTrashDescription(selectedFiles.first!.name), boldText: selectedFiles.first!.name)
            } else {
                message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalMoveTrashDescriptionPlural(selectedFiles.count))
            }

            let alert = AlertTextViewController(title: KDriveStrings.Localizable.modalMoveTrashTitle, message: message, action: KDriveStrings.Localizable.buttonMove, destructive: true, loading: true) {
                let message: String
                if let success = self.deleteFiles(Array(self.selectedFiles), async: false), success {
                    if self.selectedFiles.count == 1 {
                        message = KDriveStrings.Localizable.snackbarMoveTrashConfirmation(self.selectedFiles.first!.name)
                    } else {
                        message = KDriveStrings.Localizable.snackbarMoveTrashConfirmationPlural(self.selectedFiles.count)
                    }
                } else {
                    message = KDriveStrings.Localizable.errorMove
                }
                DispatchQueue.main.async {
                    UIConstants.showSnackBar(message: message)
                    self.selectionMode = false
                    self.getNewChanges()
                }
            }
            present(alert, animated: true)
        }

        @objc func menuButtonPressed() {
            let floatingPanelViewController = DriveFloatingPanelController()
            let selectViewController = SelectFloatingPanelTableViewController()
            floatingPanelViewController.isRemovalInteractionEnabled = true
            selectViewController.files = Array(selectedFiles)
            floatingPanelViewController.layout = PlusButtonFloatingPanelLayout(height: 200)
            selectViewController.driveFileManager = driveFileManager
            selectViewController.reloadAction = {
                self.selectionMode = false
                self.getNewChanges()
            }
            floatingPanelViewController.set(contentViewController: selectViewController)
            floatingPanelViewController.track(scrollView: selectViewController.tableView)
            self.present(floatingPanelViewController, animated: true)
        }
    #endif

    @objc func removeFileTypeButtonPressed() { }

}

// MARK: - Sort options delegate

extension FileListViewController: SortOptionsDelegate {

    func didClickOnSortingOption(type: SortType) {
        sortType = type
        if !trashSort {
            FileListOptions.instance.currentSortType = sortType
            // Collection view will be reloaded via the observer
        } else {
            reloadData()
        }
    }

}

// MARK: - Switch drive delegate

#if !ISEXTENSION
    extension FileListViewController: SwitchDriveDelegate {

        func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
            self.driveFileManager = newDriveFileManager
            currentDirectory = driveFileManager.getRootFile()
            setTitle()
            if configuration.showUploadingFiles {
                updateUploadCount()
                // We stop observing the old directory and observe the new one instead
                uploadsObserver?.cancel()
                observeUploads()
            }
            sortedFiles = []
            collectionView.reloadData()
            reloadData()
            navigationController?.popToRootViewController(animated: false)
        }

    }
#endif

// MARK: - Top scrollable

extension FileListViewController: TopScrollable {

    func scrollToTop() {
        if isViewLoaded {
            collectionView.scrollToTop(animated: true, navigationController: navigationController)
        }
    }

}
