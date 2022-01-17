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

import CocoaLumberjackSwift
import Combine
import DifferenceKit
import kDriveCore
import kDriveResources
import UIKit

class ConcreteFileListViewModel: ManagedFileListViewModel, DraggableFileListViewModel, DroppableFileListViewModel {
    var lastDropPosition: DropPosition?
}

extension SwipeCellAction {
    static let share = SwipeCellAction(identifier: "share", title: KDriveResourcesStrings.Localizable.buttonFileRights, backgroundColor: KDriveResourcesAsset.infomaniakColor.color, icon: KDriveResourcesAsset.share.image)
    static let delete = SwipeCellAction(identifier: "delete", title: KDriveResourcesStrings.Localizable.buttonDelete, backgroundColor: KDriveResourcesAsset.binColor.color, icon: KDriveResourcesAsset.delete.image)
}

extension SortType: Selectable {
    var title: String {
        return value.translation
    }
}

class MultipleSelectionBarButton: UIBarButtonItem {
    private(set) var type: MultipleSelectionBarButtonType = .cancel

    convenience init(type: MultipleSelectionBarButtonType, target: Any?, action: Selector?) {
        switch type {
        case .selectAll:
            self.init(title: KDriveResourcesStrings.Localizable.buttonSelectAll, style: .plain, target: target, action: action)
        case .deselectAll:
            self.init(title: KDriveResourcesStrings.Localizable.buttonDeselectAll, style: .plain, target: target, action: action)
        case .loading:
            let activityView = UIActivityIndicatorView(style: .medium)
            activityView.startAnimating()
            self.init(customView: activityView)
        case .cancel:
            self.init(barButtonSystemItem: .stop, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
        }
        self.type = type
    }
}

class FileListViewController: MultipleSelectionViewController, UICollectionViewDataSource, SwipeActionCollectionViewDelegate, SwipeActionCollectionViewDataSource, FilesHeaderViewDelegate {
    class var storyboard: UIStoryboard { Storyboard.files }
    class var storyboardIdentifier: String { "FileListViewController" }

    // MARK: - Constants

    private let leftRightInset = 12.0
    private let gridInnerSpacing = 16.0
    private let maxDiffChanges = Endpoint.itemsPerPage
    private let headerViewIdentifier = "FilesHeaderView"
    private let uploadCountThrottler = Throttler<Int>(timeInterval: 0.5, queue: .main)
    private let fileObserverThrottler = Throttler<File>(timeInterval: 5, queue: .global())

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
        /// Does this folder support "select all" action (no effect if multiple selection is disabled)
        var selectAllSupported = true
        /// Root folder title
        var rootTitle: String?
        /// Type of empty view to display
        var emptyViewType: EmptyTableView.EmptyTableViewType
        /// Does this folder support importing files with drop from external app
        var supportsDrop = false
        /// Does this folder support importing files with drag from external app
        var supportDrag = true
    }

    // MARK: - Properties

    var collectionViewLayout: UICollectionViewFlowLayout!
    var refreshControl = UIRefreshControl()
    private var headerView: FilesHeaderView?
    private var floatingPanelViewController: DriveFloatingPanelController!
    #if !ISEXTENSION
        private var fileInformationsViewController: FileActionsFloatingPanelViewController!
    #endif
    private var loadingBarButtonItem: UIBarButtonItem = {
        let activityView = UIActivityIndicatorView(style: .medium)
        activityView.startAnimating()
        return UIBarButtonItem(customView: activityView)
    }()

    var currentDirectory: File!

    lazy var configuration = Configuration(emptyViewType: .emptyFolder, supportsDrop: true)

    var currentDirectoryCount: FileCount?
    #if !ISEXTENSION
        lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)
    #endif

    private var uploadsObserver: ObservationToken?
    private var networkObserver: ObservationToken?

    var trashSort: Bool {
        #if ISEXTENSION
            return false
        #else
            return self is TrashViewController && currentDirectory.isRoot
        #endif
    }

    lazy var viewModel: FileListViewModel = ConcreteFileListViewModel(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)

    var bindStore = Set<AnyCancellable>()

    // MARK: - View controller lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModels()
        viewModel.onViewDidLoad()

        navigationItem.hideBackButtonText()

        // Set up collection view
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.register(UINib(nibName: headerViewIdentifier, bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerViewIdentifier)
        if configuration.isRefreshControlEnabled {
            refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
            collectionView.refreshControl = refreshControl
        }
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)
        (collectionView as? SwipableCollectionView)?.swipeDataSource = self
        (collectionView as? SwipableCollectionView)?.swipeDelegate = self
        collectionViewLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        collectionViewLayout?.sectionHeadersPinToVisibleBounds = true

        // Set up current directory
        if currentDirectory == nil {
            currentDirectory = driveFileManager?.getCachedRootFile()
        }

        // Set up multiple selection gesture
        if configuration.isMultipleSelectionEnabled {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            collectionView.addGestureRecognizer(longPressGesture)
        }
        rightBarButtonItems = navigationItem.rightBarButtonItems
        leftBarButtonItems = navigationItem.leftBarButtonItems

        if configuration.supportsDrop {
            collectionView.dropDelegate = self
        }

        if configuration.supportDrag {
            collectionView.dragDelegate = self
        }

        // Set up observers
        setUpObservers()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func bindViewModels() {
        bindFileListViewModel()
        bindUploadCardViewModel()
        bindMultipleSelectionViewModel()
    }

    private func bindFileListViewModel() {
        viewModel.onFileListUpdated = { [weak self] deletions, insertions, modifications, shouldReload in
            guard !shouldReload else {
                self?.collectionView.reloadData()
                return
            }
            self?.collectionView.performBatchUpdates {
                // Always apply updates in the following order: deletions, insertions, then modifications.
                // Handling insertions before deletions may result in unexpected behavior.
                self?.collectionView.deleteItems(at: deletions.map { IndexPath(item: $0, section: 0) })
                self?.collectionView.insertItems(at: insertions.map { IndexPath(item: $0, section: 0) })
                self?.collectionView.reloadItems(at: modifications.map { IndexPath(item: $0, section: 0) })
            }
        }

        headerView?.sortButton.setTitle(viewModel.sortType.value.translation, for: .normal)

        navigationItem.title = viewModel.title
        viewModel.$title.receiveOnMain(store: &bindStore) { [weak self] title in
            self?.navigationItem.title = title
        }

        viewModel.$isRefreshIndicatorHidden.receiveOnMain(store: &bindStore) { [weak self] isRefreshIndicatorHidden in
            guard let self = self,
                  self.refreshControl.isRefreshing == isRefreshIndicatorHidden
            else { return }

            if isRefreshIndicatorHidden {
                self.refreshControl.endRefreshing()
            } else {
                self.refreshControl.beginRefreshing()
                let offsetPoint = CGPoint(x: 0, y: self.collectionView.contentOffset.y - self.refreshControl.frame.size.height)
                self.collectionView.setContentOffset(offsetPoint, animated: true)
            }
        }

        showEmptyView(viewModel.isEmptyViewHidden)
        viewModel.$isEmptyViewHidden.receiveOnMain(store: &bindStore) { [weak self] isEmptyViewHidden in
            guard let self = self else { return }
            self.showEmptyView(isEmptyViewHidden)
        }

        headerView?.listOrGridButton.setImage(viewModel.listStyle.icon, for: .normal)
        viewModel.$listStyle.receiveOnMain(store: &bindStore) { [weak self] listStyle in
            guard let self = self else { return }
            self.headerView?.listOrGridButton.setImage(listStyle.icon, for: .normal)
            UIView.transition(with: self.collectionView, duration: 0.25, options: .transitionCrossDissolve) {
                self.collectionView.reloadData()
                self.setSelectedCells()
            }
        }

        viewModel.onDriveError = { [weak self] driveError in
            if driveError == .objectNotFound {
                self?.navigationController?.popViewController(animated: true)
            } else if driveError != .searchCancelled {
                UIConstants.showSnackBar(message: driveError.localizedDescription)
            }
        }

        viewModel.onFilePresented = { [weak self] file in
            guard let self = self else { return }
            #if !ISEXTENSION
                self.filePresenter.present(driveFileManager: self.driveFileManager,
                                           file: file,
                                           files: self.viewModel.getAllFiles(),
                                           normalFolderHierarchy: self.configuration.normalFolderHierarchy,
                                           fromActivities: self.configuration.fromActivities)
            #endif
        }
    }

    private func bindUploadCardViewModel() {
        viewModel.uploadViewModel?.$uploadCount.receiveOnMain(store: &bindStore) { [weak self] uploadCount in
            guard let self = self else { return }
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

    private func bindMultipleSelectionViewModel() {
        viewModel.multipleSelectionViewModel?.$isMultipleSelectionEnabled.receiveOnMain(store: &bindStore) { [weak self] isMultipleSelectionEnabled in
            self?.toggleMultipleSelection(isMultipleSelectionEnabled)
        }

        viewModel.multipleSelectionViewModel?.$selectedCount.receiveOnMain(store: &bindStore) { [weak self] selectedCount in
            self?.headerView?.selectView.updateTitle(selectedCount)
        }

        viewModel.multipleSelectionViewModel?.onItemSelected = { [weak self] itemIndex in
            self?.collectionView.selectItem(at: IndexPath(item: itemIndex, section: 0), animated: true, scrollPosition: .init(rawValue: 0))
        }

        viewModel.multipleSelectionViewModel?.onSelectAll = { [weak self] in
            for indexPath in self?.collectionView.indexPathsForVisibleItems ?? [] {
                self?.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
            }
        }

        viewModel.multipleSelectionViewModel?.onDeselectAll = { [weak self] in
            for indexPath in self?.collectionView.indexPathsForSelectedItems ?? [] {
                self?.collectionView.deselectItem(at: indexPath, animated: false)
            }
        }

        viewModel.multipleSelectionViewModel?.$leftBarButtons.receiveOnMain(store: &bindStore) { [weak self] leftBarButtons in
            guard let self = self else { return }
            if let leftBarButtons = leftBarButtons {
                self.navigationItem.leftBarButtonItems = leftBarButtons.map { MultipleSelectionBarButton(type: $0, target: self, action: #selector(self.multipleSelectionBarButtonPressed(_:))) }
            } else {
                self.navigationItem.leftBarButtonItems = self.leftBarButtonItems
            }
        }

        viewModel.multipleSelectionViewModel?.$rightBarButtons.receiveOnMain(store: &bindStore) { [weak self] rightBarButtons in
            guard let self = self else { return }
            if let rightBarButtons = rightBarButtons {
                self.navigationItem.rightBarButtonItems = rightBarButtons.map { MultipleSelectionBarButton(type: $0, target: self, action: #selector(self.multipleSelectionBarButtonPressed(_:))) }
            } else {
                self.navigationItem.rightBarButtonItems = self.rightBarButtonItems
            }
        }

        viewModel.multipleSelectionViewModel?.onSelectMoveDestination = { [weak self] driveFileManager, startDirectory, disabledDirectories in
            let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager,
                                                                                                                startDirectory: startDirectory,
                                                                                                                disabledDirectoriesSelection: disabledDirectories) { [weak self] selectedFolder in
                self?.viewModel.multipleSelectionViewModel?.moveSelectedItems(to: selectedFolder)
            }
            self?.present(selectFolderNavigationController, animated: true)
        }

        viewModel.multipleSelectionViewModel?.onDeleteConfirmation = { [weak self] message in
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalMoveTrashTitle,
                                                message: message,
                                                action: KDriveResourcesStrings.Localizable.buttonMove,
                                                destructive: true, loading: true) {
                self?.viewModel.multipleSelectionViewModel?.deleteSelectedItems()
            }
            self?.present(alert, animated: true)
        }

        viewModel.multipleSelectionViewModel?.onMoreButtonPressed = { [weak self] selectedItems in
            #if !ISEXTENSION
                guard let self = self else { return }
                let floatingPanelViewController = DriveFloatingPanelController()
                let selectViewController = SelectFloatingPanelTableViewController()
                floatingPanelViewController.isRemovalInteractionEnabled = true
                selectViewController.files = Array(selectedItems)
                floatingPanelViewController.layout = PlusButtonFloatingPanelLayout(height: 260)
                selectViewController.driveFileManager = self.driveFileManager
                selectViewController.reloadAction = { [unowned self] in
                    self.viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled = false
                }
                floatingPanelViewController.set(contentViewController: selectViewController)
                floatingPanelViewController.track(scrollView: selectViewController.collectionView)
                self.present(floatingPanelViewController, animated: true)
            #endif
        }
        
        viewModel.multipleSelectionViewModel?.$multipleSelectionActions.receiveOnMain(store: &bindStore) {  [weak self] actions in
            self?.headerView?.selectView.setActions(actions)
        }
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
            (tabBarController as? MainTabViewController)?.tabBar.centerButton?.isEnabled = viewModel.currentDirectory.capabilities.canCreateFile
        #endif

        viewModel.onViewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: ["FileList"])
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if let emptyView = collectionView?.backgroundView as? EmptyTableView {
            updateEmptyView(emptyView)
        }
        coordinator.animate { _ in
            self.collectionView?.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
            self.setSelectedCells()
        }
    }

    @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        guard let multipleSelectionViewModel = viewModel.multipleSelectionViewModel,
              !multipleSelectionViewModel.isMultipleSelectionEnabled
        else { return }

        let pos = sender.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: pos) {
            multipleSelectionViewModel.isMultipleSelectionEnabled = true
            // Necessary for events to trigger in the right order
            DispatchQueue.main.async { [unowned self] in
                multipleSelectionViewModel.didSelectFile(self.viewModel.getFile(at: indexPath.item), at: indexPath.item)
            }
        }
    }

    @objc func multipleSelectionBarButtonPressed(_ sender: MultipleSelectionBarButton) {
        viewModel.multipleSelectionViewModel?.barButtonPressed(type: sender.type)
    }

    @IBAction func searchButtonPressed(_ sender: Any) {
        present(SearchViewController.instantiateInNavigationController(driveFileManager: driveFileManager), animated: true)
    }

    // MARK: - Overridable methods

    func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {}

    override func getNewChanges() {}

    func setUpHeaderView(_ headerView: FilesHeaderView, isEmptyViewHidden: Bool) {
        headerView.delegate = self

        headerView.sortView.isHidden = !isEmptyViewHidden

        headerView.sortButton.setTitle(viewModel.sortType.value.translation, for: .normal)
        headerView.listOrGridButton.setImage(viewModel.listStyle.icon, for: .normal)

        if let uploadViewModel = viewModel.uploadViewModel {
            headerView.uploadCardView.isHidden = uploadViewModel.uploadCount == 0
            headerView.uploadCardView.titleLabel.text = KDriveResourcesStrings.Localizable.uploadInThisFolderTitle
            headerView.uploadCardView.setUploadCount(uploadViewModel.uploadCount)
            headerView.uploadCardView.progressView.enableIndeterminate()
        }
    }

    func updateChild(_ file: File, at index: Int) {
        let oldFile = viewModel.getFile(at: index)
        viewModel.setFile(file, at: index)

        // We don't need to call reload data if only the children were updated
        if oldFile.isContentEqual(to: file) {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
        }
    }

    // MARK: - Public methods

    final func reloadData(page: Int = 1, forceRefresh: Bool = false, showRefreshControl: Bool = true, withActivities: Bool = true) {}

    @objc func forceRefresh() {
        viewModel.forceRefresh()
    }

    final func setUpObservers() {
        // Upload files observer
        // observeUploads()
        // File observer
        // Network observer
        observeNetwork()
    }

    final func observeUploads() {}

    final func observeNetwork() {
        guard networkObserver == nil else { return }
        networkObserver = ReachabilityListener.instance.observeNetworkChange(self) { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.headerView?.offlineView.isHidden = status != .offline
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
            }
        }
    }

    final func updateUploadCount() {}

    private func showEmptyView(_ isHidden: Bool) {
        let emptyView = EmptyTableView.instantiate(type: configuration.emptyViewType, button: false)
        emptyView.actionHandler = { [weak self] _ in
            self?.forceRefresh()
        }
        collectionView.backgroundView = isHidden ? nil : emptyView
        if let headerView = headerView {
            setUpHeaderView(headerView, isEmptyViewHidden: isHidden)
        }
    }

    final func showEmptyViewIfNeeded(type: EmptyTableView.EmptyTableViewType? = nil, files: [File]) {}

    final func removeFileFromList(id: Int) {}

    static func instantiate(driveFileManager: DriveFileManager) -> Self {
        let viewController = storyboard.instantiateViewController(withIdentifier: storyboardIdentifier) as! Self
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    // MARK: - Private methods

    private func updateEmptyView(_ emptyBackground: EmptyTableView) {
        if UIDevice.current.orientation.isPortrait {
            emptyBackground.emptyImageFrameViewHeightConstant.constant = 200
        }
        if UIDevice.current.orientation.isLandscape {
            emptyBackground.emptyImageFrameViewHeightConstant.constant = 120
        }
        emptyBackground.emptyImageFrameView.cornerRadius = emptyBackground.emptyImageFrameViewHeightConstant.constant / 2
    }

    private func reloadCollectionView(with files: [File]) {}

    #if !ISEXTENSION
        private func showQuickActionsPanel(file: File) {
            if fileInformationsViewController == nil {
                fileInformationsViewController = FileActionsFloatingPanelViewController()
                fileInformationsViewController.presentingParent = self
                fileInformationsViewController.normalFolderHierarchy = configuration.normalFolderHierarchy
                floatingPanelViewController = DriveFloatingPanelController()
                floatingPanelViewController.isRemovalInteractionEnabled = true
                floatingPanelViewController.layout = FileFloatingPanelLayout(initialState: .half, hideTip: true, backdropAlpha: 0.2)
                floatingPanelViewController.set(contentViewController: fileInformationsViewController)
                floatingPanelViewController.track(scrollView: fileInformationsViewController.collectionView)
            }
            fileInformationsViewController.setFile(file, driveFileManager: driveFileManager)
            present(floatingPanelViewController, animated: true)
        }
    #endif

    // MARK: - Multiple selection

    override final func toggleMultipleSelection() {}

    func toggleMultipleSelection(_ on: Bool) {
        if on {
            navigationItem.title = nil
            headerView?.selectView.isHidden = false
            headerView?.selectView.setActions(viewModel.multipleSelectionViewModel?.multipleSelectionActions ?? [])
            collectionView.allowsMultipleSelection = true
            navigationController?.navigationBar.prefersLargeTitles = false
            let generator = UIImpactFeedbackGenerator()
            generator.prepare()
            generator.impactOccurred()
        } else {
            deselectAllChildren()
            headerView?.selectView.isHidden = true
            collectionView.allowsMultipleSelection = false
            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.title = viewModel.title
            navigationItem.rightBarButtonItems = rightBarButtonItems
            navigationItem.leftBarButtonItems = leftBarButtonItems
        }
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
    }

    override func getItem(at indexPath: IndexPath) -> File? {
        return viewModel.getFile(at: indexPath.item)
    }

    override func getAllItems() -> [File] {
        return viewModel.getAllFiles()
    }

    override final func setSelectedCells() {
        guard let multipleSelectionViewModel = viewModel.multipleSelectionViewModel else { return }
        if multipleSelectionViewModel.isSelectAllModeEnabled {
            for i in 0 ..< viewModel.fileCount {
                collectionView.selectItem(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: [])
            }
        } else {
            if multipleSelectionViewModel.isMultipleSelectionEnabled && !multipleSelectionViewModel.selectedItems.isEmpty {
                for i in 0 ..< viewModel.fileCount where multipleSelectionViewModel.selectedItems.contains(viewModel.getFile(at: i)) {
                    collectionView.selectItem(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .centeredVertically)
                }
            }
        }
    }

    override final func setSelectionButtonsEnabled(moveEnabled: Bool, deleteEnabled: Bool, moreEnabled: Bool) {}

    override final func updateSelectedCount() {}

    // MARK: - Collection view data source

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.fileCount
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerViewIdentifier, for: indexPath) as! FilesHeaderView
        setUpHeaderView(headerView, isEmptyViewHidden: viewModel.isEmptyViewHidden)
        self.headerView = headerView
        return headerView
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellType: UICollectionViewCell.Type
        switch viewModel.listStyle {
        case .list:
            cellType = FileCollectionViewCell.self
        case .grid:
            cellType = FileGridCollectionViewCell.self
        }
        let cell = collectionView.dequeueReusableCell(type: cellType, for: indexPath) as! FileCollectionViewCell

        let file = viewModel.getFile(at: indexPath.item)
        cell.initStyle(isFirst: indexPath.item == 0, isLast: indexPath.item == viewModel.fileCount - 1)
        cell.configureWith(driveFileManager: driveFileManager, file: file, selectionMode: viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true)
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
        if viewModel.multipleSelectionViewModel?.isSelectAllModeEnabled == true {
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        }
    }

    // MARK: - Collection view delegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true {
            viewModel.multipleSelectionViewModel?.didSelectFile(viewModel.getFile(at: indexPath.item), at: indexPath.item)
        } else {
            viewModel.didSelectFile(at: indexPath.item)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true else {
            return
        }
        viewModel.multipleSelectionViewModel?.didDeselectFile(viewModel.getFile(at: indexPath.item), at: indexPath.item)
    }

    // MARK: - Swipe action collection view delegate

    func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath) {
        #if !ISEXTENSION
            let file = viewModel.getFile(at: indexPath.item)
            switch action {
            case .share:
                let shareVC = ShareAndRightsViewController.instantiate(driveFileManager: driveFileManager, file: file)
                navigationController?.pushViewController(shareVC, animated: true)
            case .delete:
                delete(file: file)
            default:
                break
            }
        #endif
    }

    // MARK: - Swipe action collection view data source

    func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        if configuration.fromActivities || viewModel.listStyle == .grid {
            return nil
        }
        var actions = [SwipeCellAction]()
        let rights = viewModel.getFile(at: indexPath.item).capabilities
        if rights.canShare {
            actions.append(.share)
        }
        if rights.canDelete {
            actions.append(.delete)
        }
        return actions
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveID")
        coder.encode(viewModel.currentDirectory.id, forKey: "DirectoryID")
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
        let maybeCurrentDirectory = driveFileManager.getCachedFile(id: directoryId)
        if let currentDirectory = maybeCurrentDirectory {
            self.currentDirectory = currentDirectory
        }
        if currentDirectory == nil && directoryId > DriveFileManager.constants.rootID {
            navigationController?.popViewController(animated: true)
        }
        if configuration.showUploadingFiles {
            updateUploadCount()
        }
        observeUploads()
        reloadData()
    }

    // MARK: - Bulk actions

    private func bulkMoveFiles(_ files: [File], destinationId: Int) {
        let action = BulkAction(action: .move, fileIds: files.map(\.id), destinationDirectoryId: destinationId)
        Task {
            do {
                let response = try await driveFileManager.apiFetcher.bulkAction(drive: driveFileManager.drive, action: action)
                bulkObservation(action: .move, response: response)
            } catch {
                DDLogError("Error while moving files: \(error)")
            }
        }
    }

    private func bulkMoveAll(destinationId: Int) {
        let action = BulkAction(action: .move, parentId: currentDirectory.id, destinationDirectoryId: destinationId)
        Task {
            do {
                let response = try await driveFileManager.apiFetcher.bulkAction(drive: driveFileManager.drive, action: action)
                bulkObservation(action: .move, response: response)
            } catch {
                DDLogError("Error while moving files: \(error)")
            }
        }
    }

    private func bulkDeleteFiles(_ files: [File]) {
        let action = BulkAction(action: .trash, fileIds: files.map(\.id))
        Task {
            do {
                let response = try await driveFileManager.apiFetcher.bulkAction(drive: driveFileManager.drive, action: action)
                bulkObservation(action: .trash, response: response)
            } catch {
                DDLogError("Error while deleting files: \(error)")
            }
        }
    }

    private func bulkDeleteAll() {
        let action = BulkAction(action: .trash, parentId: currentDirectory.id)
        Task {
            do {
                let response = try await driveFileManager.apiFetcher.bulkAction(drive: driveFileManager.drive, action: action)
                bulkObservation(action: .trash, response: response)
            } catch {
                DDLogError("Error while deleting files: \(error)")
            }
        }
    }

    public func bulkObservation(action: BulkActionType, response: CancelableResponse) {
        selectionMode = false
        let message: String
        switch action {
        case .trash:
            message = KDriveResourcesStrings.Localizable.fileListDeletionStartedSnackbar
        case .move:
            message = KDriveResourcesStrings.Localizable.fileListMoveStartedSnackbar
        case .copy:
            message = KDriveResourcesStrings.Localizable.fileListCopyStartedSnackbar
        }
        let progressSnack = UIConstants.showSnackBar(message: message, duration: .infinite, action: IKSnackBar.Action(title: KDriveResourcesStrings.Localizable.buttonCancel) {
            Task {
                try await self.driveFileManager.undoAction(cancelId: response.id)
            }
        })
        AccountManager.instance.mqService.observeActionProgress(self, actionId: response.id) { [weak self] actionProgress in
            DispatchQueue.main.async {
                switch actionProgress.progress.message {
                case .starting:
                    break
                case .processing:
                    switch action {
                    case .trash:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListDeletionInProgressSnackbar(actionProgress.progress.total - actionProgress.progress.todo, actionProgress.progress.total)
                    case .move:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListMoveInProgressSnackbar(actionProgress.progress.total - actionProgress.progress.todo, actionProgress.progress.total)
                    case .copy:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListCopyInProgressSnackbar(actionProgress.progress.total - actionProgress.progress.todo, actionProgress.progress.total)
                    }
                    self?.notifyObserversForCurrentDirectory()
                case .done:
                    switch action {
                    case .trash:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListDeletionDoneSnackbar
                    case .move:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListMoveDoneSnackbar
                    case .copy:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListCopyDoneSnackbar
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        progressSnack?.dismiss()
                    }
                    self?.notifyObserversForCurrentDirectory()
                case .canceled:
                    let message: String
                    switch action {
                    case .trash:
                        message = KDriveResourcesStrings.Localizable.allTrashActionCancelled
                    case .move:
                        message = KDriveResourcesStrings.Localizable.allFileMoveCancelled
                    case .copy:
                        message = KDriveResourcesStrings.Localizable.allFileDuplicateCancelled
                    }
                    UIConstants.showSnackBar(message: message)
                    self?.notifyObserversForCurrentDirectory()
                }
            }
        }
    }

    private func notifyObserversForCurrentDirectory() {
        driveFileManager.notifyObserversWith(file: currentDirectory)
    }

    // MARK: - Files header view delegate

    func sortButtonPressed() {
        let floatingPanelViewController = FloatingPanelSelectOptionViewController<SortType>.instantiatePanel(options: trashSort ? [.nameAZ, .nameZA, .newerDelete, .olderDelete, .biggest, .smallest] : [.nameAZ, .nameZA, .newer, .older, .biggest, .smallest], selectedOption: viewModel.sortType, headerTitle: KDriveResourcesStrings.Localizable.sortTitle, delegate: self)
        present(floatingPanelViewController, animated: true)
    }

    func gridButtonPressed() {
        MatomoUtils.track(eventWithCategory: .displayList, name: listStyle == .grid ? "viewGrid" : "viewList")
        // Toggle grid/list
        FileListOptions.instance.currentStyle = viewModel.listStyle == .grid ? .list : .grid
        // Collection view will be reloaded via the observer
    }

    #if !ISEXTENSION
        func uploadCardSelected() {
            let uploadViewController = UploadQueueViewController.instantiate()
            uploadViewController.currentDirectory = currentDirectory
            navigationController?.pushViewController(uploadViewController, animated: true)
        }

        override func multipleSelectionActionButtonPressed(_ button: SelectView.MultipleSelectionActionButton) {
            viewModel.multipleSelectionViewModel?.actionButtonPressed(action: button.action)
        }
    #endif

    func removeFilterButtonPressed(_ filter: Filterable) {}
}

// MARK: - Collection view delegate flow layout

extension FileListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        switch viewModel.listStyle {
        case .list:
            // Important: subtract safe area insets
            let cellWidth = collectionView.bounds.width - collectionView.safeAreaInsets.left - collectionView.safeAreaInsets.right - leftRightInset * 2
            return CGSize(width: cellWidth, height: UIConstants.fileListCellHeight)
        case .grid:
            // Adjust cell size based on screen size
            let totalWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
            let cellWidth = floor((totalWidth - gridInnerSpacing) / 2 - leftRightInset)
            return CGSize(width: min(cellWidth, 174), height: min(floor(cellWidth * 130 / 174), 130))
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        switch viewModel.listStyle {
        case .list:
            return 0
        case .grid:
            return gridInnerSpacing
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        switch viewModel.listStyle {
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

    func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath, atCurrentIndexPath currentIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        return originalIndexPath
    }
}

// MARK: - File cell delegate

extension FileListViewController: FileCellDelegate {
    @objc func didTapMoreButton(_ cell: FileCollectionViewCell) {
        #if !ISEXTENSION
            guard let indexPath = collectionView.indexPath(for: cell) else {
                return
            }
            showQuickActionsPanel(file: viewModel.getFile(at: indexPath.item))
        #endif
    }
}

// MARK: - Sort options delegate

extension FileListViewController: SelectDelegate {
    func didSelect(option: Selectable) {
        guard let type = option as? SortType else { return }
        MatomoUtils.track(eventWithCategory: .fileList, name: "sort-\(type.rawValue)")
        if !trashSort {
            FileListOptions.instance.currentSortType = type
            // Collection view will be reloaded via the observer
        } else {
            reloadData(showRefreshControl: false)
        }
    }
}

// MARK: - Switch drive delegate

#if !ISEXTENSION
    extension FileListViewController: SwitchDriveDelegate {
        func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
            let isDifferentDrive = newDriveFileManager.drive.objectId != driveFileManager.drive.objectId
            driveFileManager = newDriveFileManager
            if configuration.showUploadingFiles {
                updateUploadCount()
                // We stop observing the old directory and observe the new one instead
                uploadsObserver?.cancel()
                uploadsObserver = nil
                observeUploads()
            }
            if isDifferentDrive {
                let currentDirectory = driveFileManager.getCachedRootFile()
                viewModel = ConcreteFileListViewModel(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
                bindViewModels()
                viewModel.onViewDidLoad()
                navigationController?.popToRootViewController(animated: false)
            }
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

// MARK: - UICollectionViewDragDelegate

extension FileListViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        return (viewModel as? DraggableFileListViewModel)?.collectionView(collectionView, itemsForBeginning: session, at: indexPath) ?? []
    }
}

// MARK: - UICollectionViewDropDelegate

extension FileListViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if let droppableViewModel = (viewModel as? DroppableFileListViewModel) {
            return droppableViewModel.collectionView(collectionView, dropSessionDidUpdate: session, withDestinationIndexPath: destinationIndexPath)
        } else {
            return UICollectionViewDropProposal(operation: .cancel, intent: .unspecified)
        }
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        (viewModel as? DroppableFileListViewModel)?.collectionView(collectionView, performDropWith: coordinator)
    }
}
