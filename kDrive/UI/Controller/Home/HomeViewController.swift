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
import kDriveCore
import UIKit

class HomeViewController: UICollectionViewController, SwitchDriveDelegate, SwitchAccountDelegate, TopScrollable {
    static let loadingCellCount = 12

    struct HomeViewModel {
        let topRows: [HomeTopRow]
        let showInsufficientStorage: Bool
        let recentFiles: [File]
        let recentFilesEmpty: Bool
        let isLoading: Bool

        init(topRows: [HomeViewController.HomeTopRow], showInsufficientStorage: Bool, recentFiles: [File], recentFilesEmpty: Bool, isLoading: Bool) {
            self.topRows = topRows
            self.showInsufficientStorage = showInsufficientStorage
            self.recentFiles = recentFiles
            self.recentFilesEmpty = recentFilesEmpty
            self.isLoading = isLoading
        }

        init(changeSet: [ArraySection<HomeSection, AnyDifferentiable>]) {
            var topRows = [HomeTopRow]()
            var showInsufficientStorage = false
            var recentFiles = [File]()
            var recentFilesEmpty = false
            var isLoading = false

            for section in changeSet {
                if section.model == .top {
                    topRows = section.elements.compactMap { $0.base as? HomeTopRow }
                    showInsufficientStorage = topRows.contains(.insufficientStorage)
                } else if section.model == .recentFiles {
                    for element in section.elements {
                        if let recentFileRow = element.base as? RecentFileRow {
                            if recentFileRow == .empty {
                                recentFilesEmpty = true
                            } else if recentFileRow == .loading {
                                isLoading = true
                            }
                        } else if let recentFileRow = element.base as? File {
                            recentFiles.append(recentFileRow)
                        } else {
                            fatalError("Invalid HomeViewController model")
                        }
                    }
                } else {
                    fatalError("Invalid HomeViewController model")
                }
            }
            self.init(topRows: topRows, showInsufficientStorage: showInsufficientStorage, recentFiles: recentFiles, recentFilesEmpty: recentFilesEmpty, isLoading: isLoading)
        }

        var stagedChangeSet: [ArraySection<HomeSection, AnyDifferentiable>] {
            var sections = [
                ArraySection(model: HomeSection.top, elements: topRows.map { AnyDifferentiable($0) })
            ]
            if recentFilesEmpty {
                sections.append(ArraySection(model: HomeSection.recentFiles, elements: [AnyDifferentiable(RecentFileRow.empty)]))
            } else {
                var anyRecentFiles = recentFiles.map { AnyDifferentiable($0) }
                if isLoading {
                    anyRecentFiles.append(contentsOf: [AnyDifferentiable](repeating: AnyDifferentiable(RecentFileRow.loading), count: HomeViewController.loadingCellCount))
                }
                sections.append(ArraySection(model: HomeSection.recentFiles, elements: anyRecentFiles))
            }
            return sections
        }
    }

    internal enum HomeSection: Differentiable, CaseIterable {
        case top
        case recentFiles
    }

    internal enum HomeTopRow: Equatable, Hashable, Differentiable {
        case offline
        case search
        case insufficientStorage
        case uploadsInProgress
        case recentFilesSelector
    }

    internal enum RecentFileRow: Differentiable {
        case file
        case loading
        case empty
    }

    private var uploadCountManager: UploadCountManager!
    var driveFileManager: DriveFileManager! {
        didSet {
            observeUploadCount()
        }
    }

    private var navbarHeight: CGFloat {
        return navigationController?.navigationBar.frame.height ?? 0
    }

    private var floatingPanelViewController: DriveFloatingPanelController?
    private var fileInformationsViewController: FileQuickActionsFloatingPanelViewController!

    private lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)
    private var recentFilesController: HomeRecentFilesController!
    private var viewModel: HomeViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = HomeViewModel(topRows: getTopRows(), showInsufficientStorage: false, recentFiles: [], recentFilesEmpty: false, isLoading: false)

        collectionView.register(supplementaryView: HomeRecentFilesHeaderView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(supplementaryView: HomeLargeTitleHeaderView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(cellView: HomeRecentFilesSelectorCollectionViewCell.self)
        collectionView.register(cellView: HomeFileSearchCollectionViewCell.self)
        collectionView.register(cellView: HomeOfflineCollectionViewCell.self)
        collectionView.register(cellView: InsufficientStorageCollectionViewCell.self)
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.register(cellView: HomeEmptyFilesCollectionViewCell.self)
        collectionView.register(cellView: FileHomeCollectionViewCell.self)
        collectionView.register(cellView: HomeLastPicCollectionViewCell.self)
        collectionView.register(WrapperCollectionViewCell.self, forCellWithReuseIdentifier: "WrapperCollectionViewCell")

        recentFilesController = HomeLastModificationsController(driveFileManager: driveFileManager, homeViewController: self)
        collectionView.collectionViewLayout = createLayout()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: navbarHeight, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: navbarHeight, left: 0, bottom: 0, right: 0)

        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] status in
            DispatchQueue.main.async {
                self?.reloadTopRows()
                if status != .offline {}
            }
        }

        recentFilesController?.loadNextPage()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.barTintColor = KDriveAsset.backgroundColor.color
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: KDriveAsset.titleColor.color]
        updateNavbarAppearance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateNavbarAppearance()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.shadowImage = nil
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.barTintColor = nil
        navigationController?.navigationBar.titleTextAttributes = nil
        navigationController?.navigationBar.alpha = 1
        navigationController?.navigationBar.isUserInteractionEnabled = true
        navigationController?.navigationBar.layoutIfNeeded()
    }

    private func getTopRows() -> [HomeTopRow] {
        var topRows: [HomeTopRow]
        if ReachabilityListener.instance.currentStatus == .offline {
            topRows = [.offline, .search]
        } else {
            topRows = [.search, .recentFilesSelector]
        }

        if uploadCountManager != nil && uploadCountManager.uploadCount > 0 {
            topRows.append(.uploadsInProgress)
        }

        guard driveFileManager != nil && driveFileManager.drive.size > 0 else {
            return topRows
        }
        let storagePercentage = Double(driveFileManager.drive.usedSize) / Double(driveFileManager.drive.size) * 100
        if (storagePercentage > UIConstants.insufficientStorageMinimumPercentage) && viewModel.showInsufficientStorage {
            topRows.append(.insufficientStorage)
        }
        return topRows
    }

    private func observeUploadCount() {
        guard driveFileManager != nil else { return }
        uploadCountManager = UploadCountManager(driveFileManager: driveFileManager) { [weak self] in
            guard let self = self else { return }
            if let index = self.viewModel.topRows.firstIndex(where: { $0 == .uploadsInProgress }),
               let cell = (self.collectionView.cellForItem(at: IndexPath(row: index, section: 0)) as? WrapperCollectionViewCell)?.subviews.first as? UploadsInProgressTableViewCell,
               self.uploadCountManager.uploadCount > 0 {
                // Update cell
                cell.setUploadCount(self.uploadCountManager.uploadCount)
            } else {
                // Delete / Add cell
                self.reloadTopRows()
            }
        }
    }

    func reloadTopRows() {
        DispatchQueue.main.async { [self] in
            let newViewModel = HomeViewModel(topRows: getTopRows(),
                                             showInsufficientStorage: viewModel.showInsufficientStorage,
                                             recentFiles: viewModel.recentFiles,
                                             recentFilesEmpty: viewModel.recentFilesEmpty,
                                             isLoading: viewModel.isLoading)
            reload(newViewModel: newViewModel)
        }
    }

    func reloadWith(fetchedFiles: [File], isEmpty: Bool) {
        var newFiles = viewModel.recentFiles
        if isEmpty {
            newFiles = []
        } else {
            newFiles.append(contentsOf: fetchedFiles)
        }
        let newViewModel = HomeViewModel(topRows: viewModel.topRows,
                                         showInsufficientStorage: viewModel.showInsufficientStorage,
                                         recentFiles: newFiles,
                                         recentFilesEmpty: isEmpty,
                                         isLoading: false)
        reload(newViewModel: newViewModel)
    }

    private func reload(newViewModel: HomeViewModel) {
        let changeset = StagedChangeset(source: viewModel.stagedChangeSet, target: newViewModel.stagedChangeSet)
        collectionView.reload(using: changeset) { data in
            self.viewModel = HomeViewModel(changeSet: data)
        }
    }

    private func updateNavbarAppearance() {
        let scrollOffset = collectionView.contentOffset.y
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }

        if UIApplication.shared.statusBarOrientation.isPortrait {
            navigationItem.title = driveFileManager?.drive.name ?? ""
            navigationBar.alpha = min(1, max(0, (scrollOffset + collectionView.contentInset.top) / navbarHeight))
            navigationBar.isUserInteractionEnabled = navigationBar.alpha > 0.5
        } else {
            navigationBar.isUserInteractionEnabled = false
            navigationItem.title = ""
            navigationBar.alpha = 0
        }
        navigationBar.layoutIfNeeded()
    }

    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] section, _ in
            guard let self = self else { return nil }
            switch HomeSection.allCases[section] {
            case .top:
                return self.generateTopSectionLayout()
            case .recentFiles:
                if self.recentFilesController.empty {
                    return self.recentFilesController.getEmptyLayout()
                } else {
                    return self.recentFilesController.getLayout(for: UserDefaults.shared.homeListStyle)
                }
            }
        }
        return layout
    }

    private func generateTopSectionLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: .fixed(0), top: .fixed(16), trailing: .fixed(0), bottom: .fixed(16))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(40))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)

        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = [header]
        return section
    }

    func presentedFromTabBar() {}

    // MARK: - Switch drive delegate

    func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
        driveFileManager = newDriveFileManager
        let driveHeaderView = collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader).first { $0 is HomeLargeTitleHeaderView } as? HomeLargeTitleHeaderView
        driveHeaderView?.titleButton.setTitle(driveFileManager.drive.name, for: .normal)
        let viewModel = HomeViewModel(topRows: getTopRows(), showInsufficientStorage: false, recentFiles: [], recentFilesEmpty: false, isLoading: true)
        reload(newViewModel: viewModel)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recentFilesController = HomeLastModificationsController(driveFileManager: self.driveFileManager, homeViewController: self)
            self.recentFilesController.loadNextPage()
        }
    }

    // MARK: - Switch account delegate

    func didUpdateCurrentAccountInformations(_ currentAccount: Account) {
        if isViewLoaded {
            reloadTopRows()
        }
    }

    func didSwitchCurrentAccount(_ newAccount: Account) {}

    // MARK: - Top scrollable

    func scrollToTop() {
        collectionView?.scrollToTop(animated: true, navigationController: nil)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let switchDriveAccountViewController = (segue.destination as? UINavigationController)?.viewControllers[0] as? SwitchDriveViewController {
            switchDriveAccountViewController.delegate = (tabBarController as? SwitchDriveDelegate)
        }
    }
}

// MARK: - UICollectionViewDataSource

extension HomeViewController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch HomeSection.allCases[section] {
        case .top:
            return viewModel.topRows.count
        case .recentFiles:
            if viewModel.recentFilesEmpty {
                return 1
            } else if viewModel.isLoading {
                return viewModel.recentFiles.count + HomeViewController.loadingCellCount
            } else {
                return viewModel.recentFiles.count
            }
        }
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return HomeSection.allCases.count
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
                    guard let self = self else { return }
                    StorePresenter.showStore(from: self, driveFileManager: self.driveFileManager)
                }
                cell.closeHandler = { [weak self] _ in
                    guard let self = self else { return }
                    let newViewModel = HomeViewModel(topRows: self.getTopRows(),
                                                     showInsufficientStorage: false,
                                                     recentFiles: self.viewModel.recentFiles,
                                                     recentFilesEmpty: self.viewModel.recentFilesEmpty,
                                                     isLoading: self.viewModel.isLoading)
                    self.reload(newViewModel: newViewModel)
                }
                return cell
            case .uploadsInProgress:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WrapperCollectionViewCell", for: indexPath) as! WrapperCollectionViewCell
                let tableCell = cell.initWith(cell: UploadsInProgressTableViewCell.self)
                tableCell.initWithPositionAndShadow(isFirst: true, isLast: true)
                tableCell.progressView.enableIndeterminate()
                tableCell.setUploadCount(uploadCountManager.uploadCount)
                return cell
            case .recentFilesSelector:
                let cell = collectionView.dequeueReusableCell(type: HomeRecentFilesSelectorCollectionViewCell.self, for: indexPath)
                cell.valueChangeHandler = { [weak self] selector in
                    guard let self = self else { return }
                    self.recentFilesController.cancelLoading()
                    switch selector.selectedSegmentIndex {
                    case 0:
                        self.recentFilesController = HomeLastModificationsController(driveFileManager: self.driveFileManager, homeViewController: self)
                    case 1:
                        self.recentFilesController = HomeOfflineFilesController(driveFileManager: self.driveFileManager, homeViewController: self)
                    case 2:
                        self.recentFilesController = HomePhotoListController(driveFileManager: self.driveFileManager, homeViewController: self)
                    default:
                        break
                    }
                    self.reload(newViewModel: HomeViewModel(topRows: self.viewModel.topRows,
                                                            showInsufficientStorage: self.viewModel.showInsufficientStorage,
                                                            recentFiles: [],
                                                            recentFilesEmpty: false,
                                                            isLoading: true))

                    let headerView = collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader).first { $0 is HomeRecentFilesHeaderView } as? HomeRecentFilesHeaderView
                    headerView?.titleLabel.text = self.recentFilesController.title

                    self.recentFilesController.loadNextPage()
                }
                return cell
            }
        case .recentFiles:
            if viewModel.recentFilesEmpty {
                let cell = collectionView.dequeueReusableCell(type: HomeEmptyFilesCollectionViewCell.self, for: indexPath)
                recentFilesController?.configureEmptyCell(cell)
                return cell
            } else {
                let cellType = UserDefaults.shared.homeListStyle == .list ? recentFilesController.listCellType : recentFilesController.gridCellType
                if let cell = collectionView.dequeueReusableCell(type: cellType, for: indexPath) as? FileCollectionViewCell {
                    if viewModel.isLoading && indexPath.row > viewModel.recentFiles.count - 1 {
                        cell.initStyle(isFirst: indexPath.row == 0, isLast: indexPath.row == viewModel.recentFiles.count - 1 + HomeViewController.loadingCellCount)
                        cell.configureLoading()
                    } else {
                        let file = viewModel.recentFiles[indexPath.row]
                        cell.delegate = self
                        cell.initStyle(isFirst: indexPath.row == 0, isLast: indexPath.row == viewModel.recentFiles.count - 1)
                        cell.configureWith(file: file, selectionMode: false)
                    }
                    return cell
                } else if let cell = collectionView.dequeueReusableCell(type: cellType, for: indexPath) as? HomeLastPicCollectionViewCell {
                    if viewModel.isLoading && indexPath.row > viewModel.recentFiles.count - 1 {
                        cell.configureLoading()
                    } else {
                        let file = viewModel.recentFiles[indexPath.row]
                        cell.configureWith(file: file)
                    }
                    return cell
                } else {
                    fatalError("Unsupported cell type")
                }
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            switch HomeSection.allCases[indexPath.section] {
            case .top:
                let driveHeaderView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, view: HomeLargeTitleHeaderView.self, for: indexPath)
                driveHeaderView.titleButton.setTitle(driveFileManager.drive.name, for: .normal)
                driveHeaderView.titleButtonPressedHandler = { [weak self] _ in
                    self?.performSegue(withIdentifier: "switchDriveSegue", sender: nil)
                }
                return driveHeaderView
            case .recentFiles:
                let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, view: HomeRecentFilesHeaderView.self, for: indexPath)
                headerView.titleLabel.text = recentFilesController.title
                headerView.switchLayoutButton.setImage(UserDefaults.shared.homeListStyle == .list ? KDriveAsset.list.image : KDriveAsset.largelist.image, for: .normal)
                headerView.actionHandler = { button in
                    UserDefaults.shared.homeListStyle = UserDefaults.shared.homeListStyle == .list ? .grid : .list
                    button.setImage(UserDefaults.shared.homeListStyle == .list ? KDriveAsset.list.image : KDriveAsset.largelist.image, for: .normal)
                    collectionView.performBatchUpdates {
                        collectionView.reloadSections([1])
                    } completion: { _ in
                    }
                }
                return headerView
            }
        } else {
            return UICollectionReusableView()
        }
    }
}

// MARK: - UICollectionViewDelegate

extension HomeViewController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateNavbarAppearance()
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch HomeSection.allCases[indexPath.section] {
        case .top:
            switch viewModel.topRows[indexPath.row] {
            case .offline, .insufficientStorage, .recentFilesSelector:
                return
            case .uploadsInProgress:
                let uploadViewController = UploadQueueFoldersViewController.instantiate(driveFileManager: driveFileManager)
                navigationController?.pushViewController(uploadViewController, animated: true)
            case .search:
                present(SearchViewController.instantiateInNavigationController(driveFileManager: driveFileManager), animated: true)
            }
        case .recentFiles:
            if !(viewModel.isLoading && indexPath.row > viewModel.recentFiles.count - 1) {
                filePresenter.present(driveFileManager: driveFileManager, file: viewModel.recentFiles[indexPath.row], files: viewModel.recentFiles, normalFolderHierarchy: false)
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if HomeSection.allCases[indexPath.section] == .recentFiles {
            if indexPath.row >= viewModel.recentFiles.count - 10 && !recentFilesController.loading && recentFilesController.moreComing {
                reload(newViewModel: HomeViewModel(topRows: viewModel.topRows,
                                                   showInsufficientStorage: viewModel.showInsufficientStorage,
                                                   recentFiles: viewModel.recentFiles,
                                                   recentFilesEmpty: false,
                                                   isLoading: true))
                recentFilesController?.loadNextPage()
            }
        }
    }
}

// MARK: - FileCellDelegate

extension HomeViewController: FileCellDelegate {
    @objc func didTapMoreButton(_ cell: FileCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        showQuickActionsPanel(file: viewModel.recentFiles[indexPath.row])
    }

    private func showQuickActionsPanel(file: File) {
        if fileInformationsViewController == nil {
            fileInformationsViewController = FileQuickActionsFloatingPanelViewController()
            fileInformationsViewController.presentingParent = self
            fileInformationsViewController.normalFolderHierarchy = true
            floatingPanelViewController = DriveFloatingPanelController()
            floatingPanelViewController?.isRemovalInteractionEnabled = true
            floatingPanelViewController?.layout = FileFloatingPanelLayout(initialState: .half, hideTip: true, backdropAlpha: 0.2)
            floatingPanelViewController?.set(contentViewController: fileInformationsViewController)
            floatingPanelViewController?.track(scrollView: fileInformationsViewController.tableView)
        }
        fileInformationsViewController.setFile(file, driveFileManager: driveFileManager)
        if let floatingPanelViewController = floatingPanelViewController {
            present(floatingPanelViewController, animated: true)
        }
    }
}
