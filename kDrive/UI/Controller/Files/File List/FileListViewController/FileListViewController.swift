/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import FloatingPanel
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

class FileListViewController: UICollectionViewController, SceneStateRestorable {
    @LazyInjectService var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var router: AppNavigable

    // MARK: - Properties

    private var paddingBottom: CGFloat {
        guard !driveFileManager.isPublicShare else {
            return UIConstants.List.publicSharePaddingBottom
        }
        return UIConstants.List.paddingBottom
    }

    let layoutHelper: FileListLayout
    let refreshControl = UIRefreshControl()
    var headerView: FilesHeaderView?
    var selectView: SelectView?

    #if !ISEXTENSION
    lazy var filePresenter = FilePresenter(viewController: self)
    #endif

    private var networkObserver: ObservationToken?

    let viewModel: FileListViewModel
    var displayedFiles = [File]()

    var bindStore = Set<AnyCancellable>()
    var currentFileLoadingTask: Task<Void, Never>?

    var driveFileManager: DriveFileManager {
        viewModel.driveFileManager
    }

    lazy var addToKDriveButton: IKLargeButton = {
        let button = IKLargeButton(frame: .zero)
        button.setTitle(KDriveCoreStrings.Localizable.buttonAddToKDrive, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(addToMyDriveButtonTapped(_:)), for: .touchUpInside)
        return button
    }()

    lazy var packId = DrivePackId(rawValue: driveFileManager.drive.pack.name)

    override var debugDescription: String {
        """
        <\(super.debugDescription) title:'\(viewModel.title)' folder id:'\(viewModel.currentDirectory.id)'>
        """
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    init(viewModel: FileListViewModel, listLayout: FileListLayout? = nil) {
        self.viewModel = viewModel
        layoutHelper = listLayout ?? DefaultFileListLayout()
        super.init(collectionViewLayout: layoutHelper.createLayoutFor(viewModel: viewModel))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hideBackButtonText()
        navigationItem.largeTitleDisplayMode = .always

        collectionView.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: paddingBottom, right: 0)
        collectionView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress)))
        collectionView.dropDelegate = self
        collectionView.dragDelegate = self

        createHeaderView()

        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)

        observeNetwork()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        setupViewModel()
        setupFooterIfNeeded()
    }

    private func createHeaderView() {
        let headerView = FilesHeaderView.instantiate()
        headerView.delegate = self
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        self.headerView = headerView
        selectView = headerView.selectView
    }

    open func setUpHeaderView(_ headerView: FilesHeaderView, isEmptyViewHidden: Bool) {
        if viewModel.currentDirectory.visibility == .isTeamSpace {
            let driveOrganisationName = viewModel.driveFileManager.drive.account.name
            let commonDocumentsDescription = KDriveResourcesStrings.Localizable.commonDocumentsDescription(driveOrganisationName)

            headerView.commonDocumentsDescriptionLabel.text = commonDocumentsDescription
            headerView.commonDocumentsDescriptionLabel.isHidden = false
        } else {
            headerView.commonDocumentsDescriptionLabel.isHidden = true
        }

        let isTrash = viewModel.currentDirectory.id == DriveFileManager.trashRootFile.id
        headerView.updateInformationView(drivePackId: packId, isTrash: isTrash)
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()

        (tabBarController as? PlusButtonObserver)?.updateCenterButton()

        tryLoadingFilesOrDisplayError()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        matomo.track(view: viewModel.configuration.matomoViewPath)

        saveSceneState()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if let emptyView = collectionView?.backgroundView as? EmptyTableView {
            updateEmptyView(emptyView)
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

    private func setupViewModel() {
        bindViewModels()
        if viewModel.configuration.isRefreshControlEnabled {
            collectionView.refreshControl = refreshControl
        }

        viewModel.startObservation()
    }

    private func bindViewModels() {
        bindFileListViewModel()
        bindUploadCardViewModel()
        bindMultipleSelectionViewModel()
    }

    private func bindFileListViewModel() {
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

        viewModel.onFilePresented = { [weak self] file in
            self?.onFilePresented(file)
        }

        viewModel.$currentLeftBarButtons.receiveOnMain(store: &bindStore) { [weak self] leftBarButtons in
            guard let self else { return }
            navigationItem.leftBarButtonItems = leftBarButtons?
                .map { FileListBarButton(type: $0, target: self, action: #selector(self.barButtonPressed(_:))) }
        }

        navigationItem.rightBarButtonItems = viewModel.currentRightBarButtons?
            .map { FileListBarButton(type: $0, target: self, action: #selector(self.barButtonPressed(_:))) }
        viewModel.$currentRightBarButtons.receiveOnMain(store: &bindStore) { [weak self] rightBarButtons in
            guard let self else { return }
            navigationItem.rightBarButtonItems = rightBarButtons?
                .map { FileListBarButton(type: $0, target: self, action: #selector(self.barButtonPressed(_:))) }
        }

        viewModel.onPresentViewController = { [weak self] presentationType, viewController, animated in
            self?.present(viewController, presentationType: presentationType, animated: animated)
        }

        viewModel.onPresentQuickActionPanel = { [weak self] files, type in
            self?.showQuickActionsPanel(files: files, actionType: type)
        }

        viewModel.$files.receiveOnMain(store: &bindStore) { [weak self] newContent in
            self?.reloadCollectionViewWith(files: newContent)
        }

        viewModel.$isShowingEmptyView.receiveOnMain(store: &bindStore) { [weak self] isShowingEmptyView in
            self?.showEmptyView(isShowingEmptyView)
        }
    }

    private func bindUploadCardViewModel() {
        viewModel.uploadViewModel?.$uploadCount
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] uploadCount in
                self?.updateUploadCard(uploadCount: uploadCount)
            }
            .store(in: &bindStore)
    }

    private func bindMultipleSelectionViewModel() {
        viewModel.multipleSelectionViewModel?.$isMultipleSelectionEnabled
            .receiveOnMain(store: &bindStore) { [weak self] isMultipleSelectionEnabled in
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
            for i in 0 ..< (self?.viewModel.files.count ?? 0) {
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

    func setupFooterIfNeeded() {
        guard case .publicShare(_, let metadata) = driveFileManager.context, metadata.capabilities.canDownload else { return }

        view.addSubview(addToKDriveButton)
        view.bringSubviewToFront(addToKDriveButton)

        let leadingConstraint = addToKDriveButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor,
                                                                           constant: 16)
        leadingConstraint.priority = .defaultHigh
        let trailingConstraint = addToKDriveButton.trailingAnchor.constraint(
            greaterThanOrEqualTo: view.trailingAnchor,
            constant: -16
        )
        trailingConstraint.priority = .defaultHigh
        let widthConstraint = addToKDriveButton.widthAnchor.constraint(lessThanOrEqualToConstant: 360)

        NSLayoutConstraint.activate([
            addToKDriveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            leadingConstraint,
            trailingConstraint,
            addToKDriveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addToKDriveButton.heightAnchor.constraint(equalToConstant: 60),
            widthConstraint
        ])
    }

    @objc func addToMyDriveButtonTapped(_ sender: UIButton?) {
        defer {
            sender?.isSelected = false
            sender?.isEnabled = true
            sender?.isHighlighted = false
        }

        guard accountManager.currentAccount != nil else {
            #if !ISEXTENSION
            let upsaleFloatingPanelController = UpsaleViewController.instantiateInFloatingPanel(rootViewController: self)
            present(upsaleFloatingPanelController, animated: true, completion: nil)
            #else
            dismiss(animated: true)
            #endif

            return
        }

        viewModel.barButtonPressed(sender: sender, type: .addToMyDrive)
    }

    func reloadCollectionViewWith(files: [File]) {
        let changeSet = StagedChangeset(source: displayedFiles, target: files)
        collectionView.reload(using: changeSet,
                              interrupt: { $0.changeCount > Endpoint.itemsPerPage },
                              setData: { self.displayedFiles = $0 })

        if let headerView {
            setUpHeaderView(headerView, isEmptyViewHidden: viewModel.isShowingEmptyView)
        }
    }

    func getDisplayedFile(at indexPath: IndexPath) -> File? {
        return displayedFiles[safe: indexPath.item]
    }

    private func toggleRefreshing(_ refreshing: Bool) {
        if refreshing {
            refreshControl.beginRefreshing()
        } else {
            refreshControl.endRefreshing()
        }
    }

    private func updateListStyle(_ listStyle: ListStyle) {
        headerView?.listOrGridButton.setImage(listStyle.icon, for: .normal)
        let newLayout = layoutHelper.createLayoutFor(viewModel: viewModel)

        if !displayedFiles.isEmpty {
            collectionView.reloadSections([0])
        }
        collectionView.setCollectionViewLayout(newLayout, animated: true)
        setSelectedCells()
    }

    private func present(_ viewController: UIViewController, presentationType: ControllerPresentationType, animated: Bool) {
        if presentationType == .push,
           let navigationController {
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
        }
    }

    private func fileFloatingPanelLayout(files: [File]) -> FloatingPanelLayout {
        guard driveFileManager.isPublicShare else {
            return FileFloatingPanelLayout(
                initialState: .half,
                hideTip: true,
                backdropAlpha: 0.2
            )
        }

        if let publicShareMetadata = driveFileManager.publicShareMetadata,
           !publicShareMetadata.capabilities.canDownload {
            return FileFloatingPanelLayout(
                initialState: .tip,
                hideTip: false,
                backdropAlpha: 0.2
            )
        } else if files.first?.isDirectory == true {
            return PublicShareFolderFloatingPanelLayout(
                initialState: .half,
                hideTip: true,
                backdropAlpha: 0.2
            )
        } else {
            return PublicShareFileFloatingPanelLayout(
                initialState: .half,
                hideTip: true,
                backdropAlpha: 0.2
            )
        }
    }

    private func showQuickActionsPanel(files: [File], actionType: FileListQuickActionType) {
        #if !ISEXTENSION
        var floatingPanelViewController: DriveFloatingPanelController
        switch actionType {
        case .file:
            guard let file = files.first else {
                DDLogError("[FileListViewController] Unable to show quick actions panel without a file")
                return
            }

            floatingPanelViewController = DriveFloatingPanelController()
            let fileInformationsViewController = FileActionsFloatingPanelViewController(frozenFile: file,
                                                                                        driveFileManager: driveFileManager)

            fileInformationsViewController.presentingParent = self
            fileInformationsViewController.normalFolderHierarchy = viewModel.configuration.normalFolderHierarchy

            floatingPanelViewController.layout = fileFloatingPanelLayout(files: files)
            floatingPanelViewController.set(contentViewController: fileInformationsViewController)
            floatingPanelViewController.track(scrollView: fileInformationsViewController.collectionView)
        case .trash:
            floatingPanelViewController = AdaptiveDriveFloatingPanelController()
            let trashFloatingPanelTableViewController = TrashFloatingPanelTableViewController()
            trashFloatingPanelTableViewController.delegate = (viewModel as? TrashListViewModel)

            trashFloatingPanelTableViewController.trashedFiles = files

            floatingPanelViewController.set(contentViewController: trashFloatingPanelTableViewController)
            (floatingPanelViewController as? AdaptiveDriveFloatingPanelController)?
                .trackAndObserve(scrollView: trashFloatingPanelTableViewController.tableView)
        case .multipleSelection(let downloadOnly):
            let allItemsSelected: Bool
            let forceMoveDistinctFiles: Bool
            let exceptFileIds: [Int]?
            let selectedFiles: [File]
            if viewModel.multipleSelectionViewModel?.isSelectAllModeEnabled == true {
                allItemsSelected = true
                selectedFiles = displayedFiles
                exceptFileIds = Array(viewModel.multipleSelectionViewModel?.exceptItemIds ?? Set<Int>())
            } else {
                allItemsSelected = false
                selectedFiles = files
                exceptFileIds = nil
            }

            if viewModel.multipleSelectionViewModel?.forceMoveDistinctFiles == true {
                forceMoveDistinctFiles = true
            } else {
                forceMoveDistinctFiles = false
            }
            let selectViewController = MultipleSelectionFloatingPanelViewController(
                driveFileManager: driveFileManager,
                currentDirectory: viewModel.currentDirectory,
                files: selectedFiles,
                allItemsSelected: allItemsSelected,
                forceMoveDistinctFiles: forceMoveDistinctFiles,
                exceptFileIds: exceptFileIds,
                reloadAction: { [weak self] in
                    self?.viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled = false
                },
                presentingParent: self
            )

            if downloadOnly {
                selectViewController.actions = [.download]
            }

            floatingPanelViewController = AdaptiveDriveFloatingPanelController()
            floatingPanelViewController.set(contentViewController: selectViewController)
            (floatingPanelViewController as? AdaptiveDriveFloatingPanelController)?
                .trackAndObserve(scrollView: selectViewController.collectionView)
        }
        floatingPanelViewController.isRemovalInteractionEnabled = true
        present(floatingPanelViewController, animated: true)
        #endif
    }

    private func updateEmptyView(_ emptyBackground: EmptyTableView) {
        let isSpaceLimited = traitCollection.verticalSizeClass == .compact && traitCollection.horizontalSizeClass == .compact
        emptyBackground.emptyImageFrameViewHeightConstant.constant = isSpaceLimited ? 120 : 200
        emptyBackground.emptyImageFrameView.cornerRadius = emptyBackground.emptyImageFrameViewHeightConstant.constant / 2
    }

    private func tryLoadingFilesOrDisplayError() {
        guard !viewModel.isLoading else { return }

        currentFileLoadingTask = Task {
            do {
                try await self.viewModel.loadFiles()
            } catch {
                if let driveError = error as? DriveError,
                   driveError == .objectNotFound {
                    navigationController?.popViewController(animated: true)
                } else {
                    UIConstants.showSnackBarIfNeeded(error: error)
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
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let file = getDisplayedFile(at: indexPath) {
                    multipleSelectionViewModel.didSelectFile(file, at: indexPath)
                }
            }
        }
    }

    @objc func barButtonPressed(_ sender: FileListBarButton) {
        viewModel.barButtonPressed(sender: sender, type: sender.type)
    }

    @objc func forceRefresh() {
        viewModel.forceRefresh()
    }

    // MARK: - Public methods

    func onFilePresented(_ file: File) {
        #if !ISEXTENSION
        filePresenter.present(for: file,
                              files: viewModel.files,
                              driveFileManager: viewModel.driveFileManager,
                              normalFolderHierarchy: viewModel.configuration.normalFolderHierarchy,
                              presentationOrigin: viewModel.configuration.presentationOrigin)
        #endif
    }

    private func observeNetwork() {
        guard networkObserver == nil else { return }
        networkObserver = ReachabilityListener.instance.observeNetworkChange(self) { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                self.headerView?.offlineView.isHidden = status != .offline
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
            }
        }
    }

    func showEmptyView(_ isShowing: Bool) {
        guard (collectionView.backgroundView == nil) == isShowing || headerView?.sortView.isHidden == !isShowing else { return }
        let emptyView = EmptyTableView.instantiate(type: bestEmptyViewType(), button: false)
        emptyView.actionHandler = { [weak self] _ in
            self?.forceRefresh()
        }
        collectionView.backgroundView = isShowing ? emptyView : nil
        if let headerView {
            setUpHeaderView(headerView, isEmptyViewHidden: !isShowing)
        }
    }

    private func bestEmptyViewType() -> EmptyTableView.EmptyTableViewType {
        var type = viewModel.configuration.emptyViewType
        if tabBarController?.tabBar.isHidden == false,
           type == .emptyFolder && viewModel.currentDirectory.capabilities.canCreateFile {
            type = .emptyFolderWithCreationRights
        }
        return type
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
            for i in 0 ..< viewModel.files.count {
                collectionView.selectItem(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: [])
            }
        } else {
            if multipleSelectionViewModel.isMultipleSelectionEnabled && !multipleSelectionViewModel.selectedItems.isEmpty {
                /*
                 Scroll to the selected cells only if the view is currently visible
                 Scrolling when the view is not visible causes the layout to break
                 */
                let scrollPosition: UICollectionView.ScrollPosition = viewIfLoaded?.window != nil ? .centeredVertically : []
                for i in 0 ..< viewModel.files.count {
                    guard let file = getDisplayedFile(at: IndexPath(item: i, section: 0)),
                          multipleSelectionViewModel.selectedItems.contains(file) else {
                        continue
                    }
                    collectionView.selectItem(at: IndexPath(item: i, section: 0), animated: false, scrollPosition: scrollPosition)
                }
            }
        }
    }

    // MARK: - FilesHeaderViewDelegate - Subclasses override

    func removeFilterButtonPressed(_ filter: Filterable) {
        // Overriden in subclasses
    }

    // MARK: - State restoration

    var currentSceneMetadata: [AnyHashable: Any] {
        [
            SceneRestorationKeys.lastViewController.rawValue: SceneRestorationScreens.FileListViewController.rawValue,
            SceneRestorationValues.driveId.rawValue: driveFileManager.driveId,
            SceneRestorationValues.fileId.rawValue: viewModel.currentDirectory.id
        ]
    }
}

// MARK: - UICollectionViewDataSource

extension FileListViewController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return displayedFiles.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellType: UICollectionViewCell.Type
        switch viewModel.listStyle {
        case .list:
            cellType = FileCollectionViewCell.self
        case .grid:
            cellType = FileGridCollectionViewCell.self
        }

        let cell = collectionView.dequeueReusableCell(type: cellType, for: indexPath) as! FileCollectionViewCell
        let file = displayedFiles[indexPath.row]

        cell.initStyle(isFirst: file.isFirstInList, isLast: file.isLastInList, inFolderSelectMode: false)
        cell.configureWith(
            driveFileManager: viewModel.driveFileManager,
            file: file,
            selectionMode: viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true
        )
        cell.delegate = self
        if ReachabilityListener.instance.currentStatus == .offline && !file.isDirectory && !file.isAvailableOffline {
            cell.setEnabled(false)
        } else {
            cell.setEnabled(true)
        }

        if viewModel.configuration.presentationOrigin == PresentationOrigin.activities {
            cell.moreButton.isHidden = true
        }

        return cell
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if viewModel.multipleSelectionViewModel?.isSelectAllModeEnabled == true,
           let file = getDisplayedFile(at: indexPath),
           viewModel.multipleSelectionViewModel?.exceptItemIds.contains(file.id) != true {
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        }
        (cell as? FileCollectionViewCell)?
            .setSelectionMode(viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true)
    }
}

// MARK: - UICollectionViewDelegate

extension FileListViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true {
            guard let file = getDisplayedFile(at: indexPath) else { return }
            viewModel.multipleSelectionViewModel?.didSelectFile(file, at: indexPath)
        } else {
            viewModel.didSelectFile(at: indexPath)
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true,
              let file = getDisplayedFile(at: indexPath) else {
            return
        }
        viewModel.multipleSelectionViewModel?.didDeselectFile(file, at: indexPath)
    }
}

// MARK: - FileCellDelegate

extension FileListViewController: FileCellDelegate {
    func didTapMoreButton(_ cell: FileCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        viewModel.didTapMore(at: indexPath)
    }
}

// MARK: - TopScrollable

extension FileListViewController: TopScrollable {
    func scrollToTop() {
        if isViewLoaded {
            collectionView.scrollToTop(animated: true, navigationController: navigationController)
        }
    }
}
