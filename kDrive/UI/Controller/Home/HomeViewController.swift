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

import DifferenceKit
import InfomaniakCore
import InfomaniakCoreUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class HomeViewController: CustomLargeTitleCollectionViewController, UpdateAccountDelegate, TopScrollable,
    SelectSwitchDriveDelegate {
    private static let loadingCellCount = 12

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var navigationManager: NavigationManageable

    enum HomeFileType {
        case file([File])
        case fileActivity([FileActivity])
    }

    struct HomeViewModel {
        let topRows: [HomeTopRow]
        let recentFiles: HomeFileType
        let recentFilesEmpty: Bool
        let isLoading: Bool

        var recentFilesCount: Int {
            switch recentFiles {
            case .file(let files):
                return files.count
            case .fileActivity(let activities):
                return activities.count
            }
        }

        init(topRows: [HomeViewController.HomeTopRow], recentFiles: HomeFileType, recentFilesEmpty: Bool, isLoading: Bool) {
            self.topRows = topRows
            self.recentFiles = recentFiles
            self.recentFilesEmpty = recentFilesEmpty
            self.isLoading = isLoading
        }

        init(changeSet: [ArraySection<HomeSection, AnyDifferentiable>]) {
            var topRows = [HomeTopRow]()
            var recentFiles = [File]()
            var recentActivities = [FileActivity]()
            var recentFilesEmpty = false
            var isLoading = false

            for section in changeSet {
                switch section.model {
                case .top:
                    topRows = section.elements.compactMap { $0.base as? HomeTopRow }
                case .recentFiles:
                    for element in section.elements {
                        if let recentFileRow = element.base as? RecentFileRow {
                            if recentFileRow == .empty {
                                recentFilesEmpty = true
                            } else if recentFileRow == .loading {
                                isLoading = true
                            }
                        } else if let recentFileRow = element.base as? File {
                            recentFiles.append(recentFileRow)
                        } else if let recentActivityRow = element.base as? FileActivity {
                            recentActivities.append(recentActivityRow)
                        } else {
                            fatalError("Invalid HomeViewController model")
                        }
                    }
                }
            }

            if recentFiles.isEmpty {
                self.init(
                    topRows: topRows,
                    recentFiles: .fileActivity(recentActivities),
                    recentFilesEmpty: recentFilesEmpty,
                    isLoading: isLoading
                )
            } else {
                self.init(
                    topRows: topRows,
                    recentFiles: .file(recentFiles),
                    recentFilesEmpty: recentFilesEmpty,
                    isLoading: isLoading
                )
            }
        }

        lazy var changeSet: [ArraySection<HomeSection, AnyDifferentiable>] = {
            var sections = [
                ArraySection(model: HomeSection.top, elements: topRows.map { AnyDifferentiable($0) })
            ]
            if recentFilesEmpty {
                sections.append(ArraySection(model: HomeSection.recentFiles, elements: [AnyDifferentiable(RecentFileRow.empty)]))
            } else {
                var anyRecentFiles = [AnyDifferentiable]()
                switch recentFiles {
                case .file(let files):
                    anyRecentFiles = files.map { AnyDifferentiable($0) }
                case .fileActivity(let activities):
                    anyRecentFiles = activities.map { AnyDifferentiable($0) }
                }

                if isLoading {
                    anyRecentFiles
                        .append(contentsOf: [AnyDifferentiable](repeating: AnyDifferentiable(RecentFileRow.loading),
                                                                count: HomeViewController.loadingCellCount))
                }
                sections.append(ArraySection(model: HomeSection.recentFiles, elements: anyRecentFiles))
            }
            return sections
        }()
    }

    enum HomeSection: Differentiable, CaseIterable {
        case top
        case recentFiles
    }

    enum HomeTopRow: Differentiable {
        case offline
        case search
        case insufficientStorage
        case uploadsInProgress
    }

    enum RecentFileRow: Differentiable {
        case file
        case loading
        case empty
    }

    private var uploadCountManager: UploadCountManager!
    var driveFileManager: DriveFileManager! {
        didSet {
            observeUploadCount()
            observeFileUpdated()
        }
    }

    private var floatingPanelViewController: DriveFloatingPanelController?
    private var fileInformationsViewController: FileActionsFloatingPanelViewController!
    private lazy var filePresenter = FilePresenter(viewController: self)

    private var recentActivitiesController: HomeRecentActivitiesController?

    private let reloadQueue = DispatchQueue(label: "com.infomaniak.drive.reloadQueue", qos: .userInitiated)
    private lazy var viewModel = HomeViewModel(
        topRows: getTopRows(),
        recentFiles: .file([]),
        recentFilesEmpty: false,
        isLoading: false
    )
    private var showInsufficientStorage = true
    private var filesObserver: ObservationToken?

    private let refreshControl = UIRefreshControl()

    init(driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
        super.init(collectionViewLayout: .init())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = driveFileManager.drive.name

        collectionView.backgroundColor = KDriveResourcesAsset.backgroundColor.color

        collectionView.register(supplementaryView: HomeRecentFilesHeaderView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(supplementaryView: HomeLargeTitleHeaderView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(cellView: HomeFileSearchCollectionViewCell.self)
        collectionView.register(cellView: HomeOfflineCollectionViewCell.self)
        collectionView.register(cellView: InsufficientStorageCollectionViewCell.self)
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.register(cellView: HomeEmptyFilesCollectionViewCell.self)
        collectionView.register(cellView: FileHomeCollectionViewCell.self)
        collectionView.register(cellView: RecentActivityCollectionViewCell.self)
        collectionView.register(WrapperCollectionViewCell.self, forCellWithReuseIdentifier: "WrapperCollectionViewCell")

        collectionView.collectionViewLayout = createLayout()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)
        collectionView.refreshControl = refreshControl

        navigationItem.hideBackButtonText()

        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)

        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            Task { [weak self] in
                self?.reloadTopRows()
            }
        }

        initRecentActivitiesController()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: ["Home"])
    }

    func observeFileUpdated() {
        guard driveFileManager != nil else { return }
        filesObserver?.cancel()
        filesObserver = driveFileManager.observeFileUpdated(self, fileId: nil) { [weak self] file in
            guard let self else { return }
            recentActivitiesController?.refreshIfNeeded(with: file)
        }
    }

    private func observeUploadCount() {
        guard driveFileManager != nil else { return }

        uploadCountManager = UploadCountManager(driveFileManager: driveFileManager) { [weak self] in
            guard let self else { return }

            guard let cell = getUploadsInProgressTableViewCell(),
                  uploadCountManager.uploadCount > 0 else {
                // Delete / Add cell
                reloadTopRows()
                return
            }

            // Update cell
            cell.setUploadCount(uploadCountManager.uploadCount)
        }
    }

    private func getUploadsInProgressTableViewCell() -> UploadsInProgressTableViewCell? {
        guard let index = viewModel.topRows.firstIndex(where: { $0 == .uploadsInProgress }) else {
            return nil
        }

        guard let wrapperCell = collectionView.cellForItem(at: IndexPath(row: index, section: 0)) as? WrapperCollectionViewCell
        else {
            return nil
        }

        guard let cell = wrapperCell.wrappedCell as? UploadsInProgressTableViewCell else {
            return nil
        }

        return cell
    }

    private func getTopRows() -> [HomeTopRow] {
        var topRows: [HomeTopRow]
        if ReachabilityListener.instance.currentStatus == .offline {
            topRows = [.offline, .search]
        } else {
            topRows = [.search]
        }

        if uploadCountManager != nil && uploadCountManager.uploadCount > 0 {
            topRows.append(.uploadsInProgress)
        }

        guard driveFileManager != nil && driveFileManager.drive.size > 0 else {
            return topRows
        }
        let storagePercentage = Double(driveFileManager.drive.usedSize) / Double(driveFileManager.drive.size) * 100
        if (storagePercentage > UIConstants.insufficientStorageMinimumPercentage) && showInsufficientStorage {
            topRows.append(.insufficientStorage)
        }
        return topRows
    }

    func reloadTopRows() {
        let newViewModel = HomeViewModel(topRows: getTopRows(),
                                         recentFiles: viewModel.recentFiles,
                                         recentFilesEmpty: viewModel.recentFilesEmpty,
                                         isLoading: viewModel.isLoading)
        reload(newViewModel: newViewModel)
    }

    func reloadWith(fetchedFiles: HomeFileType, isEmpty: Bool) {
        refreshControl.endRefreshing()
        let newViewModel = HomeViewModel(topRows: viewModel.topRows,
                                         recentFiles: fetchedFiles,
                                         recentFilesEmpty: isEmpty,
                                         isLoading: false)
        reload(newViewModel: newViewModel)
    }

    private func reload(newViewModel: HomeViewModel) {
        reloadQueue.async { [weak self] in
            guard let self else { return }
            var newViewModel = newViewModel
            let newChangeset = newViewModel.changeSet
            let oldChangeset = viewModel.changeSet
            let changeset = StagedChangeset(source: oldChangeset, target: newChangeset)
            DispatchQueue.main.sync {
                self.collectionView.reload(using: changeset) { data in
                    self.viewModel = HomeViewModel(changeSet: data)
                }
            }
        }
    }

    @objc func forceRefresh() {
        recentActivitiesController?.invalidated = true
        let viewModel = HomeViewModel(topRows: getTopRows(), recentFiles: .file([]), recentFilesEmpty: false, isLoading: true)
        reload(newViewModel: viewModel)
        initRecentActivitiesController()
    }

    private func initRecentActivitiesController() {
        let emptyViewModel = HomeViewModel(
            topRows: viewModel.topRows,
            recentFiles: .file([]),
            recentFilesEmpty: false,
            isLoading: false
        )
        reload(newViewModel: emptyViewModel)

        recentActivitiesController?.invalidated = true

        let recentActivitiesController = HomeRecentActivitiesController(
            driveFileManager: driveFileManager,
            homeViewController: self
        )
        self.recentActivitiesController = recentActivitiesController

        let headerView = collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
            .compactMap { $0 as? HomeRecentFilesHeaderView }.first
        headerView?.titleLabel.text = recentActivitiesController.title

        if recentActivitiesController.nextCursor == nil {
            reload(newViewModel: HomeViewModel(topRows: viewModel.topRows,
                                               recentFiles: .file([]),
                                               recentFilesEmpty: false,
                                               isLoading: true))
            recentActivitiesController.loadNextPage()
        } else {
            reload(newViewModel: HomeViewModel(topRows: viewModel.topRows,
                                               recentFiles: .file([]),
                                               recentFilesEmpty: false,
                                               isLoading: false))
            recentActivitiesController.restoreCachedPages()
        }
    }

    private func createLayout() -> UICollectionViewLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.boundarySupplementaryItems = [HomeViewController.generateHeaderItem()]

        let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak self] section, layoutEnvironment in
            guard let self else { return nil }
            switch HomeSection.allCases[section] {
            case .top:
                return generateTopSectionLayout()
            case .recentFiles:
                if recentActivitiesController?.empty == true {
                    return recentActivitiesController?.getEmptyLayout()
                } else {
                    return recentActivitiesController?.getLayout(
                        for: UserDefaults.shared.homeListStyle,
                        layoutEnvironment: layoutEnvironment
                    )
                }
            }
        }, configuration: configuration)
        return layout
    }

    private func generateTopSectionLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.edgeSpacing = NSCollectionLayoutEdgeSpacing(
            leading: .fixed(0),
            top: .fixed(16),
            trailing: .fixed(0),
            bottom: .fixed(16)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        return section
    }

    func presentedFromTabBar() {
        recentActivitiesController?.refreshIfNeeded()
    }

    // MARK: - Switch account delegate

    func didUpdateCurrentAccountInformations(_ currentAccount: Account) {
        if isViewLoaded {
            reloadTopRows()
        }
    }

    // MARK: - Top scrollable

    func scrollToTop() {
        collectionView?.scrollToTop(animated: true, navigationController: nil)
    }
}

// MARK: - UICollectionViewDataSource

extension HomeViewController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.changeSet[section].elements.count
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.changeSet.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch HomeSection.allCases[indexPath.section] {
        case .top:
            switch viewModel.topRows[indexPath.row] {
            case .offline:
                let cell = collectionView.dequeueReusableCell(type: HomeOfflineCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                return cell
            case .search:
                let cell = collectionView.dequeueReusableCell(type: HomeFileSearchCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                return cell
            case .insufficientStorage:
                let cell = collectionView.dequeueReusableCell(type: InsufficientStorageCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.configureCell(with: driveFileManager.drive)
                cell.actionHandler = { [weak self] _ in
                    guard let self else { return }
                    navigationManager.showStore(from: self, driveFileManager: driveFileManager)
                }
                cell.closeHandler = { [weak self] _ in
                    guard let self else { return }
                    showInsufficientStorage = false
                    let newViewModel = HomeViewModel(topRows: getTopRows(),
                                                     recentFiles: viewModel.recentFiles,
                                                     recentFilesEmpty: viewModel.recentFilesEmpty,
                                                     isLoading: viewModel.isLoading)
                    reload(newViewModel: newViewModel)
                }
                return cell
            case .uploadsInProgress:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: "WrapperCollectionViewCell",
                    for: indexPath
                ) as! WrapperCollectionViewCell
                let tableCell = cell.reuse(withCellType: UploadsInProgressTableViewCell.self)
                tableCell.initWithPositionAndShadow(isFirst: true, isLast: true)
                tableCell.progressView.enableIndeterminate()
                tableCell.setUploadCount(uploadCountManager.uploadCount)
                return cell
            }
        case .recentFiles:
            if viewModel.recentFilesEmpty {
                let cell = collectionView.dequeueReusableCell(type: HomeEmptyFilesCollectionViewCell.self, for: indexPath)
                recentActivitiesController?.configureEmptyCell(cell)
                return cell
            } else if let cellType = recentActivitiesController?.listCellType,
                      let cell = collectionView.dequeueReusableCell(
                          type: cellType,
                          for: indexPath
                      ) as? RecentActivityCollectionViewCell {
                cell.initWithPositionAndShadow()
                if viewModel.isLoading && indexPath.row > viewModel.recentFilesCount - 1 {
                    cell.configureLoading()
                } else {
                    if case .fileActivity(let activities) = viewModel.recentFiles {
                        let activity = activities[indexPath.row]
                        cell.configureWith(recentActivity: activity)
                        cell.delegate = self
                    }
                }
                return cell
            } else {
                fatalError("Unsupported cell type")
            }
        }
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            switch HomeSection.allCases[indexPath.section] {
            case .top:
                let driveHeaderView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    view: HomeLargeTitleHeaderView.self,
                    for: indexPath
                )
                driveHeaderView.isEnabled = accountManager.drives.count > 1
                driveHeaderView.text = driveFileManager.drive.name
                driveHeaderView.titleButtonPressedHandler = { [weak self] _ in
                    guard let self else { return }
                    let drives = accountManager.drives
                    let floatingPanelViewController = FloatingPanelSelectOptionViewController<Drive>.instantiatePanel(
                        options: drives,
                        selectedOption: driveFileManager.drive,
                        headerTitle: KDriveResourcesStrings.Localizable.buttonSwitchDrive,
                        delegate: self
                    )
                    present(floatingPanelViewController, animated: true)
                }
                headerViewHeight = driveHeaderView.frame.height
                return driveHeaderView
            case .recentFiles:
                let headerView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    view: HomeRecentFilesHeaderView.self,
                    for: indexPath
                )
                headerView.titleLabel.text = recentActivitiesController?.title ?? ""
                return headerView
            }
        } else {
            return UICollectionReusableView()
        }
    }
}

// MARK: - UICollectionViewDelegate

extension HomeViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch HomeSection.allCases[indexPath.section] {
        case .top:
            switch viewModel.topRows[indexPath.row] {
            case .offline, .insufficientStorage:
                return
            case .uploadsInProgress:
                let uploadViewController = UploadQueueFoldersViewController.instantiate(driveFileManager: driveFileManager)
                navigationController?.pushViewController(uploadViewController, animated: true)
            case .search:
                let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager)
                present(SearchViewController.instantiateInNavigationController(viewModel: viewModel), animated: true)
            }
        case .recentFiles:
            if !(viewModel.isLoading && indexPath.row > viewModel.recentFilesCount - 1), !viewModel.recentFilesEmpty {
                switch viewModel.recentFiles {
                case .file(let files):
                    filePresenter.present(
                        for: files[indexPath.row],
                        files: files,
                        driveFileManager: driveFileManager,
                        normalFolderHierarchy: false
                    )
                case .fileActivity:
                    break
                }
            }
        }
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let recentActivitiesController else { return }

        if HomeSection.allCases[indexPath.section] == .recentFiles {
            if indexPath.row >= viewModel.recentFilesCount - 10 &&
                !recentActivitiesController.loading &&
                recentActivitiesController.moreComing {
                reload(newViewModel: HomeViewModel(topRows: viewModel.topRows,
                                                   recentFiles: viewModel.recentFiles,
                                                   recentFilesEmpty: false,
                                                   isLoading: true))
                recentActivitiesController.loadNextPage()
            }
        }
    }
}

// MARK: - FileCellDelegate

extension HomeViewController: FileCellDelegate {
    func didTapMoreButton(_ cell: FileCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }

        if case .file(let files) = viewModel.recentFiles {
            showQuickActionsPanel(file: files[indexPath.row])
        }
    }

    private func showQuickActionsPanel(file: File) {
        if fileInformationsViewController == nil {
            fileInformationsViewController = FileActionsFloatingPanelViewController()
            fileInformationsViewController.presentingParent = self
            fileInformationsViewController.normalFolderHierarchy = true
            floatingPanelViewController = DriveFloatingPanelController()
            floatingPanelViewController?.isRemovalInteractionEnabled = true
            floatingPanelViewController?.layout = FileFloatingPanelLayout(initialState: .half, hideTip: true, backdropAlpha: 0.2)
            floatingPanelViewController?.set(contentViewController: fileInformationsViewController)
            floatingPanelViewController?.track(scrollView: fileInformationsViewController.collectionView)
        }
        fileInformationsViewController.setFile(file, driveFileManager: driveFileManager)
        if let floatingPanelViewController {
            present(floatingPanelViewController, animated: true)
        }
    }
}

// MARK: - RecentActivityDelegate

extension HomeViewController: RecentActivityDelegate {
    func didSelectActivity(index: Int, activities: [FileActivity]) {
        let activity = activities[index]
        guard let file = activity.file else {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorPreviewDeleted)
            return
        }

        if activities.count > 3 && index > 1 {
            let nextVC = RecentActivityFilesViewController.instantiate(activities: activities, driveFileManager: driveFileManager)
            filePresenter.navigationController?.pushViewController(nextVC, animated: true)
        } else {
            filePresenter.present(
                for: driveFileManager.getManagedFile(from: file),
                files: activities.compactMap(\.file),
                driveFileManager: driveFileManager,
                normalFolderHierarchy: false
            )
        }
    }
}
