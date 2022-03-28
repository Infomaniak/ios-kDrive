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
import InfomaniakCore
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

extension SwipeCellAction {
    static let share = SwipeCellAction(identifier: "share", title: KDriveResourcesStrings.Localizable.buttonFileRights, backgroundColor: KDriveResourcesAsset.infomaniakColor.color, icon: KDriveResourcesAsset.share.image)
    static let delete = SwipeCellAction(identifier: "delete", title: KDriveResourcesStrings.Localizable.buttonDelete, backgroundColor: KDriveResourcesAsset.binColor.color, icon: KDriveResourcesAsset.delete.image)
}

extension SortType: Selectable {
    var title: String {
        return value.translation
    }
}

class FileListBarButton: UIBarButtonItem {
    private(set) var type: FileListBarButtonType = .cancel

    convenience init(type: FileListBarButtonType, target: Any?, action: Selector?) {
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
        case .search:
            self.init(barButtonSystemItem: .search, target: target, action: action)
        case .emptyTrash:
            self.init(title: KDriveResourcesStrings.Localizable.buttonEmptyTrash, style: .plain, target: target, action: action)
        case .searchFilters:
            self.init(image: KDriveResourcesAsset.filter.image, style: .plain, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.filtersTitle
        case .photoSort:
            self.init(image: KDriveResourcesAsset.filter.image, style: .plain, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.sortTitle
        case .addFolder:
            self.init(image: KDriveResourcesAsset.folderAdd.image, style: .plain, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.createFolderTitle
        }
        self.type = type
    }
}

class ConcreteFileListViewModel: FileListViewModel {
    required convenience init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        let configuration = FileListViewModel.Configuration(emptyViewType: .emptyFolder, supportsDrop: true, rightBarButtons: [.search])
        self.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
    }

    override init(configuration: FileListViewModel.Configuration, driveFileManager: DriveFileManager, currentDirectory: File?) {
        let currentDirectory = currentDirectory ?? driveFileManager.getCachedRootFile(freeze: false)
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        files = AnyRealmCollection(AnyRealmCollection(currentDirectory.children).filesSorted(by: sortType))
    }

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) async throws {
        guard !isLoading || page > 1 else { return }

        if currentDirectory.canLoadChildrenFromCache && !forceRefresh {
            try await loadActivitiesIfNeeded()
        } else {
            startRefreshing(page: page)
            defer {
                endRefreshing()
            }

            let (_, moreComing) = try await driveFileManager.files(in: currentDirectory.proxify(), page: page, sortType: sortType, forceRefresh: forceRefresh)
            endRefreshing()
            if moreComing {
                try await loadFiles(page: page + 1, forceRefresh: forceRefresh)
            } else if !forceRefresh {
                try await loadActivities()
            }
        }
    }

    override func loadActivities() async throws {
        _ = try await driveFileManager.fileActivities(file: currentDirectory.proxify())
    }

    override func barButtonPressed(type: FileListBarButtonType) {
        if type == .search {
            let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager)
            let searchViewController = SearchViewController.instantiateInNavigationController(viewModel: viewModel)
            onPresentViewController?(.modal, searchViewController, true)
        } else {
            super.barButtonPressed(type: type)
        }
    }
}

class FileListViewController: UIViewController, UICollectionViewDataSource, SwipeActionCollectionViewDelegate, SwipeActionCollectionViewDataSource, FilesHeaderViewDelegate {
    class var storyboard: UIStoryboard { Storyboard.files }
    class var storyboardIdentifier: String { "FileListViewController" }

    // MARK: - Constants

    private let leftRightInset = 12.0
    private let gridInnerSpacing = 16.0
    private let headerViewIdentifier = "FilesHeaderView"

    // MARK: - Properties

    @IBOutlet weak var collectionView: UICollectionView!
    var collectionViewLayout: UICollectionViewFlowLayout!
    var refreshControl = UIRefreshControl()
    private var headerView: FilesHeaderView?
    var selectView: SelectView?

    #if !ISEXTENSION
        lazy var filePresenter = FilePresenter(viewController: self)
    #endif

    private var networkObserver: ObservationToken?

    var viewModel: FileListViewModel!

    var bindStore = Set<AnyCancellable>()
    var currentFileLoadingTask: Task<Void, Never>?

    // MARK: - View controller lifecycle

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hideBackButtonText()

        // Set up collection view
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.register(UINib(nibName: headerViewIdentifier, bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerViewIdentifier)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)
        (collectionView as? SwipableCollectionView)?.swipeDataSource = self
        (collectionView as? SwipableCollectionView)?.swipeDelegate = self
        collectionViewLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        collectionViewLayout?.sectionHeadersPinToVisibleBounds = true

        // Set up observers
        observeNetwork()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        if viewModel != nil {
            setupViewModel()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()

        #if !ISEXTENSION
            let plusButtonDirectory: File
            if viewModel.currentDirectory.id >= DriveFileManager.constants.rootID {
                plusButtonDirectory = viewModel.currentDirectory
            } else {
                plusButtonDirectory = viewModel.driveFileManager.getCachedRootFile()
            }
            (tabBarController as? MainTabViewController)?.tabBar.centerButton?.isEnabled = plusButtonDirectory.capabilities.canCreateFile
        #endif

        tryLoadingFilesOrDisplayError()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: viewModel.configuration.matomoViewPath)
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

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            currentFileLoadingTask?.cancel()
        }
    }

    @objc func appWillEnterForeground() {
        viewWillAppear(true)
    }

    // MARK: - Private methods

    private func setupViewModel() {
        bindViewModels()
        if viewModel.configuration.isRefreshControlEnabled {
            refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
            collectionView.refreshControl = refreshControl
        }
        // Set up multiple selection gesture
        if viewModel.multipleSelectionViewModel != nil {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            collectionView.addGestureRecognizer(longPressGesture)
        }

        if viewModel.droppableFileListViewModel != nil {
            collectionView.dropDelegate = self
        }

        if viewModel.draggableFileListViewModel != nil {
            collectionView.dragDelegate = self
        }

        viewModel.startObservation()
    }

    private func bindViewModels() {
        bindFileListViewModel()
        bindUploadCardViewModel()
        bindMultipleSelectionViewModel()
    }

    private func bindFileListViewModel() {
        viewModel.onFileListUpdated = { [weak self] deletions, insertions, modifications, moved, isEmpty, shouldReload in
            self?.showEmptyView(!isEmpty)
            if shouldReload {
                self?.collectionView.reloadData()
            } else {
                self?.updateFileList(deletions: deletions, insertions: insertions, modifications: modifications, moved: moved)
            }
        }

        headerView?.sortButton.setTitle(viewModel.sortType.value.translation, for: .normal)

        navigationItem.title = viewModel.title
        viewModel.$title.receiveOnMain(store: &bindStore) { [weak self] title in
            self?.navigationItem.title = title
        }

        viewModel.$isRefreshing.receiveOnMain(store: &bindStore) { [weak self] isRefreshing in
            self?.toggleRefreshing(isRefreshing)
        }

        viewModel.$listStyle.receiveOnMain(store: &bindStore) { [weak self] listStyle in
            self?.updateListStyle(listStyle)
        }

        #if !ISEXTENSION
            viewModel.onFilePresented = { [weak self] file in
                guard let self = self else { return }
                self.filePresenter.present(driveFileManager: self.viewModel.driveFileManager,
                                           file: file,
                                           files: self.viewModel.getAllFiles(),
                                           normalFolderHierarchy: self.viewModel.configuration.normalFolderHierarchy,
                                           fromActivities: self.viewModel.configuration.fromActivities)
            }
        #endif

        viewModel.$currentLeftBarButtons.receiveOnMain(store: &bindStore) { [weak self] leftBarButtons in
            guard let self = self else { return }
            self.navigationItem.leftBarButtonItems = leftBarButtons?.map { FileListBarButton(type: $0, target: self, action: #selector(self.barButtonPressed(_:))) }
        }

        navigationItem.rightBarButtonItems = viewModel.currentRightBarButtons?.map { FileListBarButton(type: $0, target: self, action: #selector(self.barButtonPressed(_:))) }
        viewModel.$currentRightBarButtons.receiveOnMain(store: &bindStore) { [weak self] rightBarButtons in
            guard let self = self else { return }
            self.navigationItem.rightBarButtonItems = rightBarButtons?.map { FileListBarButton(type: $0, target: self, action: #selector(self.barButtonPressed(_:))) }
        }

        viewModel.onPresentViewController = { [weak self] presentationType, viewController, animated in
            self?.present(viewController, presentationType: presentationType, animated: animated)
        }

        viewModel.onPresentQuickActionPanel = { [weak self] files, type in
            self?.showQuickActionsPanel(files: files, actionType: type)
        }
    }

    private func bindUploadCardViewModel() {
        viewModel.uploadViewModel?.$uploadCount.receiveOnMain(store: &bindStore) { [weak self] uploadCount in
            self?.updateUploadCard(uploadCount: uploadCount)
        }
    }

    private func bindMultipleSelectionViewModel() {
        viewModel.multipleSelectionViewModel?.$isMultipleSelectionEnabled.receiveOnMain(store: &bindStore) { [weak self] isMultipleSelectionEnabled in
            self?.toggleMultipleSelection(isMultipleSelectionEnabled)
        }

        viewModel.multipleSelectionViewModel?.$selectedCount.receiveOnMain(store: &bindStore) { [weak self] selectedCount in
            guard self?.viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true else { return }
            self?.selectView?.updateTitle(selectedCount)
        }

        viewModel.multipleSelectionViewModel?.onItemSelected = { [weak self] selectedIndexPath in
            self?.collectionView.selectItem(at: selectedIndexPath, animated: true, scrollPosition: .init(rawValue: 0))
        }

        viewModel.multipleSelectionViewModel?.onSelectAll = { [weak self] in
            for i in 0 ..< (self?.viewModel.fileCount ?? 0) {
                self?.collectionView.selectItem(at: IndexPath(row: i, section: 0), animated: true, scrollPosition: [])
            }
        }

        viewModel.multipleSelectionViewModel?.onDeselectAll = { [weak self] in
            for indexPath in self?.collectionView.indexPathsForSelectedItems ?? [] {
                self?.collectionView.deselectItem(at: indexPath, animated: true)
            }
        }

        viewModel.multipleSelectionViewModel?.$multipleSelectionActions.receiveOnMain(store: &bindStore) { [weak self] actions in
            self?.selectView?.setActions(actions)
        }
    }

    func getViewModel(viewModelName: String, driveFileManager: DriveFileManager, currentDirectory: File?) -> FileListViewModel? {
        if let viewModelClass = Bundle.main.classNamed("kDrive.\(viewModelName)") as? FileListViewModel.Type {
            return viewModelClass.init(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        } else {
            return nil
        }
    }

    private func updateFileList(deletions: [Int], insertions: [Int], modifications: [Int], moved: [(source: Int, target: Int)]) {
        collectionView.performBatchUpdates {
            // Always apply updates in the following order: deletions, insertions, then modifications.
            // Handling insertions before deletions may result in unexpected behavior.
            collectionView.deleteItems(at: deletions.map { IndexPath(item: $0, section: 0) })
            collectionView.insertItems(at: insertions.map { IndexPath(item: $0, section: 0) })
            collectionView.reloadItems(at: modifications.map { IndexPath(item: $0, section: 0) })
            for (source, target) in moved {
                collectionView.moveItem(at: IndexPath(item: source, section: 0), to: IndexPath(item: target, section: 0))
            }
        }
        // Reload corners (outside of batch to prevent incompatible operations)
        reloadFileCorners(insertions: insertions, deletions: deletions)
    }

    private func toggleRefreshing(_ refreshing: Bool) {
        if refreshing {
            refreshControl.beginRefreshing()
            let offsetPoint = CGPoint(x: 0, y: collectionView.contentOffset.y - refreshControl.frame.size.height)
            collectionView.setContentOffset(offsetPoint, animated: true)
        } else {
            refreshControl.endRefreshing()
        }
    }

    private func updateListStyle(_ listStyle: ListStyle) {
        headerView?.listOrGridButton.setImage(listStyle.icon, for: .normal)
        UIView.transition(with: collectionView, duration: 0.25, options: .transitionCrossDissolve) {
            self.collectionView.reloadData()
            self.setSelectedCells()
        }
    }

    private func present(_ viewController: UIViewController, presentationType: ControllerPresentationType, animated: Bool) {
        if presentationType == .push,
           let navigationController = navigationController {
            navigationController.pushViewController(viewController, animated: animated)
        } else {
            present(viewController, animated: animated)
        }
    }

    private func updateUploadCard(uploadCount: Int) {
        let shouldHideUploadCard: Bool
        if uploadCount > 0 {
            headerView?.uploadCardView.setUploadCount(uploadCount)
            shouldHideUploadCard = false
        } else {
            shouldHideUploadCard = true
        }
        // Only perform reload if needed
        if shouldHideUploadCard != headerView?.uploadCardView.isHidden {
            headerView?.uploadCardView.isHidden = shouldHideUploadCard
            collectionView.performBatchUpdates(nil)
        }
    }

    private func showQuickActionsPanel(files: [File], actionType: FileListQuickActionType) {
        #if !ISEXTENSION
            var floatingPanelViewController: DriveFloatingPanelController
            switch actionType {
            case .file:
                floatingPanelViewController = DriveFloatingPanelController()
                let fileInformationsViewController = FileActionsFloatingPanelViewController()

                fileInformationsViewController.presentingParent = self
                fileInformationsViewController.normalFolderHierarchy = viewModel.configuration.normalFolderHierarchy

                floatingPanelViewController.layout = FileFloatingPanelLayout(initialState: .half, hideTip: true, backdropAlpha: 0.2)

                if let file = files.first {
                    fileInformationsViewController.setFile(file, driveFileManager: driveFileManager)
                }

                floatingPanelViewController.set(contentViewController: fileInformationsViewController)
                floatingPanelViewController.track(scrollView: fileInformationsViewController.collectionView)
            case .trash:
                floatingPanelViewController = AdaptiveDriveFloatingPanelController()
                let trashFloatingPanelTableViewController = TrashFloatingPanelTableViewController()
                trashFloatingPanelTableViewController.delegate = (viewModel as? TrashListViewModel)

                trashFloatingPanelTableViewController.trashedFiles = files

                floatingPanelViewController.set(contentViewController: trashFloatingPanelTableViewController)
                (floatingPanelViewController as? AdaptiveDriveFloatingPanelController)?.trackAndObserve(scrollView: trashFloatingPanelTableViewController.tableView)
            case .multipleSelection:
                floatingPanelViewController = AdaptiveDriveFloatingPanelController()
                let selectViewController = MultipleSelectionFloatingPanelViewController()
                selectViewController.presentingParent = self

                if viewModel.multipleSelectionViewModel?.isSelectAllModeEnabled == true {
                    selectViewController.allItemsSelected = true
                    selectViewController.exceptFileIds = Array(viewModel.multipleSelectionViewModel?.exceptItemIds ?? Set<Int>())
                    selectViewController.parentId = viewModel.currentDirectory.id
                } else {
                    selectViewController.allItemsSelected = false
                    selectViewController.files = files
                }
                selectViewController.driveFileManager = driveFileManager
                selectViewController.reloadAction = { [weak self] in
                    self?.viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled = false
                }

                floatingPanelViewController.set(contentViewController: selectViewController)
                (floatingPanelViewController as? AdaptiveDriveFloatingPanelController)?.trackAndObserve(scrollView: selectViewController.collectionView)
            }
            floatingPanelViewController.isRemovalInteractionEnabled = true
            present(floatingPanelViewController, animated: true)
        #endif
    }

    private func reloadFileCorners(insertions: [Int], deletions: [Int]) {
        reloadCorners(insertions: insertions, deletions: deletions, count: viewModel.fileCount)
    }

    private func updateEmptyView(_ emptyBackground: EmptyTableView) {
        if UIDevice.current.orientation.isPortrait {
            emptyBackground.emptyImageFrameViewHeightConstant.constant = 200
        }
        if UIDevice.current.orientation.isLandscape {
            emptyBackground.emptyImageFrameViewHeightConstant.constant = 120
        }
        emptyBackground.emptyImageFrameView.cornerRadius = emptyBackground.emptyImageFrameViewHeightConstant.constant / 2
    }

    private func tryLoadingFilesOrDisplayError() {
        guard !viewModel.isLoading else { return }

        currentFileLoadingTask = Task {
            do {
                try await self.viewModel.loadFiles()
            } catch let driveError as DriveError {
                if driveError == .objectNotFound {
                    navigationController?.popViewController(animated: true)
                } else if driveError != .searchCancelled {
                    UIConstants.showSnackBar(message: driveError.localizedDescription)
                }
            } catch {
                if error.asAFError?.isExplicitlyCancelledError != true {
                    UIConstants.showSnackBar(message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Actions

    @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        guard let multipleSelectionViewModel = viewModel.multipleSelectionViewModel,
              !multipleSelectionViewModel.isMultipleSelectionEnabled
        else { return }

        let pos = sender.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: pos) {
            multipleSelectionViewModel.isMultipleSelectionEnabled = true
            // Necessary for events to trigger in the right order
            DispatchQueue.main.async { [unowned self] in
                if let file = self.viewModel.getFile(at: indexPath) {
                    multipleSelectionViewModel.didSelectFile(file, at: indexPath)
                }
            }
        }
    }

    @objc func barButtonPressed(_ sender: FileListBarButton) {
        viewModel.barButtonPressed(type: sender.type)
    }

    @objc func forceRefresh() {
        viewModel.forceRefresh()
    }

    // MARK: - Public methods

    func setUpHeaderView(_ headerView: FilesHeaderView, isEmptyViewHidden: Bool) {
        headerView.delegate = self

        headerView.sortView.isHidden = !isEmptyViewHidden

        headerView.sortButton.isHidden = viewModel.configuration.sortingOptions.isEmpty
        UIView.performWithoutAnimation {
            headerView.sortButton.setTitle(viewModel.sortType.value.translation, for: .normal)
            headerView.sortButton.layoutIfNeeded()
            headerView.listOrGridButton.setImage(viewModel.listStyle.icon, for: .normal)
            headerView.listOrGridButton.layoutIfNeeded()
        }

        if let uploadViewModel = viewModel.uploadViewModel {
            headerView.uploadCardView.isHidden = uploadViewModel.uploadCount == 0
            headerView.uploadCardView.titleLabel.text = KDriveResourcesStrings.Localizable.uploadInThisFolderTitle
            headerView.uploadCardView.setUploadCount(uploadViewModel.uploadCount)
            headerView.uploadCardView.progressView.enableIndeterminate()
        }
    }

    private func observeNetwork() {
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

    private func showEmptyView(_ isHidden: Bool) {
        let emptyView = EmptyTableView.instantiate(type: viewModel.configuration.emptyViewType, button: false)
        emptyView.actionHandler = { [weak self] _ in
            self?.forceRefresh()
        }
        collectionView.backgroundView = isHidden ? nil : emptyView
        if let headerView = headerView {
            setUpHeaderView(headerView, isEmptyViewHidden: isHidden)
        }
    }

    class func instantiate(viewModel: FileListViewModel) -> Self {
        let viewController = storyboard.instantiateViewController(withIdentifier: storyboardIdentifier) as! Self
        viewController.viewModel = viewModel
        return viewController
    }

    func reloadCorners(insertions: [Int], deletions: [Int], count: Int) {
        var modifications = Set<IndexPath>()
        if insertions.contains(0) {
            modifications.insert(IndexPath(row: 1, section: 0))
        }
        if deletions.contains(0) {
            modifications.insert(IndexPath(row: 0, section: 0))
        }
        if insertions.contains(count - 1) {
            modifications.insert(IndexPath(row: count - 2, section: 0))
        }
        if deletions.contains(count) {
            modifications.insert(IndexPath(row: count - 1, section: 0))
        }
        collectionView.reloadItems(at: Array(modifications))
    }

    // MARK: - Multiple selection

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
            headerView?.selectView.isHidden = true
            collectionView.allowsMultipleSelection = false
            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.title = viewModel.title
        }
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
    }

    func setSelectedCells() {
        guard let multipleSelectionViewModel = viewModel.multipleSelectionViewModel else { return }
        if multipleSelectionViewModel.isSelectAllModeEnabled {
            for i in 0 ..< viewModel.fileCount {
                collectionView.selectItem(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: [])
            }
        } else {
            if multipleSelectionViewModel.isMultipleSelectionEnabled && !multipleSelectionViewModel.selectedItems.isEmpty {
                for i in 0 ..< viewModel.fileCount where multipleSelectionViewModel.selectedItems.contains(viewModel.getFile(at: IndexPath(item: i, section: 0))!) {
                    collectionView.selectItem(at: IndexPath(item: i, section: 0), animated: false, scrollPosition: .centeredVertically)
                }
            }
        }
    }

    // MARK: - Collection view data source

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.fileCount
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let dequeuedHeaderView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerViewIdentifier, for: indexPath) as! FilesHeaderView
        setUpHeaderView(dequeuedHeaderView, isEmptyViewHidden: !viewModel.isEmpty)

        headerView = dequeuedHeaderView
        selectView = dequeuedHeaderView.selectView
        return dequeuedHeaderView
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

        let file = viewModel.getFile(at: indexPath)!
        cell.initStyle(isFirst: indexPath.item == 0, isLast: indexPath.item == viewModel.fileCount - 1)
        cell.configureWith(driveFileManager: viewModel.driveFileManager, file: file, selectionMode: viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true)
        cell.delegate = self
        if ReachabilityListener.instance.currentStatus == .offline && !file.isDirectory && !file.isAvailableOffline {
            cell.setEnabled(false)
        } else {
            cell.setEnabled(true)
        }
        if viewModel.configuration.fromActivities {
            cell.moreButton.isHidden = true
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if viewModel.multipleSelectionViewModel?.isSelectAllModeEnabled == true,
           let file = viewModel.getFile(at: indexPath),
           viewModel.multipleSelectionViewModel?.exceptItemIds.contains(file.id) != true {
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        }
    }

    // MARK: - Collection view delegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true {
            viewModel.multipleSelectionViewModel?.didSelectFile(viewModel.getFile(at: indexPath)!, at: indexPath)
        } else {
            viewModel.didSelectFile(at: indexPath)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true,
              let file = viewModel.getFile(at: indexPath) else {
            return
        }
        viewModel.multipleSelectionViewModel?.didDeselectFile(file, at: indexPath)
    }

    // MARK: - Swipe action collection view delegate

    func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath) {
        viewModel.didSelectSwipeAction(action, at: indexPath)
    }

    // MARK: - Swipe action collection view data source

    func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        return viewModel.getSwipeActions(at: indexPath)
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(viewModel.driveFileManager.drive.id, forKey: "DriveID")
        coder.encode(viewModel.currentDirectory.id, forKey: "DirectoryID")
        if let viewModel = viewModel {
            coder.encode(String(describing: type(of: viewModel)), forKey: "ViewModel")
        }
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveID")
        let directoryId = coder.decodeInteger(forKey: "DirectoryID")
        let viewModelName = coder.decodeObject(of: NSString.self, forKey: "ViewModel") as String?

        // Drive File Manager should be consistent
        let maybeDriveFileManager: DriveFileManager?
        #if ISEXTENSION
            maybeDriveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId)
        #else
            if !(viewModel is SharedWithMeViewModel) {
                maybeDriveFileManager = (tabBarController as? MainTabViewController)?.driveFileManager
            } else {
                maybeDriveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId)
            }
        #endif
        guard let driveFileManager = maybeDriveFileManager else {
            // Handle error?
            return
        }
        let maybeCurrentDirectory = driveFileManager.getCachedFile(id: directoryId)

        if !(maybeCurrentDirectory == nil && directoryId > DriveFileManager.constants.rootID),
           let viewModelName = viewModelName,
           let viewModel = getViewModel(viewModelName: viewModelName, driveFileManager: driveFileManager, currentDirectory: maybeCurrentDirectory) {
            self.viewModel = viewModel
            setupViewModel()
            tryLoadingFilesOrDisplayError()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Files header view delegate

    func sortButtonPressed() {
        viewModel.sortButtonPressed()
    }

    func gridButtonPressed() {
        viewModel.listStyleButtonPressed()
    }

    #if !ISEXTENSION
        func uploadCardSelected() {
            let uploadViewController = UploadQueueViewController.instantiate()
            uploadViewController.currentDirectory = viewModel.currentDirectory
            navigationController?.pushViewController(uploadViewController, animated: true)
        }
    #endif

    func multipleSelectionActionButtonPressed(_ button: SelectView.MultipleSelectionActionButton) {
        viewModel.multipleSelectionViewModel?.actionButtonPressed(action: button.action)
    }

    func removeFilterButtonPressed(_ filter: Filterable) {
        // Overriden in subclasses
    }
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
    func didTapMoreButton(_ cell: FileCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        viewModel.didTapMore(at: indexPath)
    }
}

// MARK: - Switch drive delegate

#if !ISEXTENSION
    extension FileListViewController: SwitchDriveDelegate {
        var driveFileManager: DriveFileManager! {
            get {
                viewModel.driveFileManager
            }
            set {
                guard viewModel != nil else { return }
                let isDifferentDrive = newValue.drive.objectId != driveFileManager.drive.objectId
                if isDifferentDrive {
                    viewModel = (type(of: viewModel) as FileListViewModel.Type).init(driveFileManager: newValue)
                } else {
                    viewModel.driveFileManager = newValue
                }
            }
        }

        func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
            let isDifferentDrive = newDriveFileManager.drive.objectId != driveFileManager.drive.objectId
            if isDifferentDrive {
                viewModel = (type(of: viewModel) as FileListViewModel.Type).init(driveFileManager: newDriveFileManager)
                bindViewModels()
                tryLoadingFilesOrDisplayError()
                navigationController?.popToRootViewController(animated: false)
            } else {
                viewModel.driveFileManager = newDriveFileManager
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
        if let draggableViewModel = viewModel.draggableFileListViewModel,
           let draggedFile = viewModel.getFile(at: indexPath) {
            return draggableViewModel.dragItems(for: draggedFile, in: collectionView, at: indexPath, with: session)
        } else {
            return []
        }
    }
}

// MARK: - UICollectionViewDropDelegate

extension FileListViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if let droppableViewModel = viewModel.droppableFileListViewModel {
            let file = destinationIndexPath != nil ? viewModel.getFile(at: destinationIndexPath!) : nil
            return droppableViewModel.updateDropSession(session, in: collectionView, with: destinationIndexPath, destinationFile: file)
        } else {
            return UICollectionViewDropProposal(operation: .cancel, intent: .unspecified)
        }
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        if let droppableViewModel = viewModel.droppableFileListViewModel {
            var destinationDirectory = viewModel.currentDirectory

            if let indexPath = coordinator.destinationIndexPath,
               indexPath.item < viewModel.fileCount,
               let file = viewModel.getFile(at: indexPath),
               file.isDirectory && file.capabilities.canUpload {
                destinationDirectory = file
            }

            droppableViewModel.performDrop(with: coordinator, in: collectionView, destinationDirectory: destinationDirectory)
        }
    }
}
