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
import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class HomeViewController: CustomLargeTitleCollectionViewController, UpdateAccountDelegate, TopScrollable,
    SelectSwitchDriveDelegate {
    private static let loadingCellCount = 12

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var router: AppNavigable
    @InjectService var appRouter: AppNavigable

    private var isCompactView: Bool {
        guard let rootViewController = appRouter.rootViewController else { return false }
        return rootViewController.traitCollection.horizontalSizeClass == .compact
    }

    struct HomeViewModel {
        let topRows: [HomeTopRow]
        let recentFiles: [FileActivity]
        let isLoading: Bool

        var recentFilesCount: Int {
            recentFiles.count
        }

        init(topRows: [HomeViewController.HomeTopRow], recentFiles: [FileActivity], isLoading: Bool) {
            self.topRows = topRows
            self.recentFiles = recentFiles
            self.isLoading = isLoading
        }

        init(changeSet: [ArraySection<HomeSection, AnyDifferentiable>]) {
            var topRows = [HomeTopRow]()
            var recentActivities = [FileActivity]()
            var isLoading = false

            for section in changeSet {
                switch section.model {
                case .top:
                    topRows = section.elements.compactMap { $0.base as? HomeTopRow }
                case .recentFiles:
                    for element in section.elements {
                        if let recentFileRow = element.base as? RecentFileRow {
                            if recentFileRow == .loading {
                                isLoading = true
                            }
                        } else if let recentActivityRow = element.base as? FileActivity {
                            recentActivities.append(recentActivityRow)
                        } else {
                            fatalError("Invalid HomeViewController model")
                        }
                    }
                }
            }

            self.init(
                topRows: topRows,
                recentFiles: recentActivities,
                isLoading: isLoading
            )
        }

        lazy var changeSet: [ArraySection<HomeSection, AnyDifferentiable>] = {
            var sections = [
                ArraySection(model: HomeSection.top, elements: topRows.map { AnyDifferentiable($0) })
            ]

            var anyRecentFiles: [AnyDifferentiable] = recentFiles.map { AnyDifferentiable($0) }

            if isLoading {
                anyRecentFiles
                    .append(contentsOf: [AnyDifferentiable](repeating: AnyDifferentiable(RecentFileRow.loading),
                                                            count: HomeViewController.loadingCellCount))
            }
            sections.append(ArraySection(model: HomeSection.recentFiles, elements: anyRecentFiles))

            return sections
        }()
    }

    enum HomeSection: Differentiable, CaseIterable {
        case top
        case recentFiles
    }

    enum HomeTopRow: Differentiable {
        case insufficientStorage
    }

    enum RecentFileRow: Differentiable {
        case file
        case loading
    }

    var driveFileManager: DriveFileManager

    private var floatingPanelViewController: DriveFloatingPanelController?
    private var fileInformationsViewController: FileActionsFloatingPanelViewController!
    private lazy var filePresenter = FilePresenter(viewController: self)

    private var recentActivitiesController: HomeRecentActivitiesController?

    private let reloadQueue = DispatchQueue(label: "com.infomaniak.drive.reloadQueue", qos: .userInitiated)
    private lazy var viewModel = HomeViewModel(
        topRows: getTopRows(),
        recentFiles: [],
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

        if isCompactView {
            navigationItem.title = driveFileManager.drive.name
        }

        collectionView.backgroundColor = KDriveResourcesAsset.backgroundColor.color

        collectionView.register(supplementaryView: HomeRecentFilesHeaderView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(supplementaryView: HomeLargeTitleHeaderView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(supplementaryView: RootMenuHeaderView.self, forSupplementaryViewOfKind: RootMenuHeaderView.kind)
        collectionView.register(cellView: InsufficientStorageCollectionViewCell.self)
        collectionView.register(cellView: RecentActivityCollectionViewCell.self)

        collectionView.collectionViewLayout = createLayout()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.List.paddingBottom, right: 0)
        collectionView.refreshControl = refreshControl

        navigationItem.hideBackButtonText()

        let searchButton = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(searchButtonPressed))
        navigationItem.rightBarButtonItems = [searchButton]

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
        matomo.track(view: ["Home"])

        saveSceneState()
    }

    @objc func searchButtonPressed() {
        let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager)
        present(SearchViewController.instantiateInNavigationController(viewModel: viewModel), animated: true)
    }

    private func getTopRows() -> [HomeTopRow] {
        var topRows: [HomeTopRow] = []

        guard driveFileManager.drive.size > 0 else {
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
                                         isLoading: viewModel.isLoading)
        reload(newViewModel: newViewModel)
    }

    func reloadWith(fetchedFiles: [FileActivity], isEmpty: Bool) {
        refreshControl.endRefreshing()
        let newViewModel = HomeViewModel(topRows: viewModel.topRows,
                                         recentFiles: fetchedFiles,
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
        let viewModel = HomeViewModel(
            topRows: getTopRows(),
            recentFiles: [],
            isLoading: true
        )
        reload(newViewModel: viewModel)
        initRecentActivitiesController()
    }

    private func initRecentActivitiesController() {
        let emptyViewModel = HomeViewModel(
            topRows: viewModel.topRows,
            recentFiles: [],
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
                                               recentFiles: [],
                                               isLoading: true))
            recentActivitiesController.loadNextPage()
        } else {
            reload(newViewModel: HomeViewModel(topRows: viewModel.topRows,
                                               recentFiles: [],
                                               isLoading: false))
            recentActivitiesController.restoreCachedPages()
        }
    }

    private func createLayout() -> UICollectionViewLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.boundarySupplementaryItems = [HomeViewController.generateHeaderItem()]

        let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak self] section, _ in
            guard let self else { return nil }
            switch HomeSection.allCases[section] {
            case .top:
                return generateTopSectionLayout()
            case .recentFiles:
                if recentActivitiesController?.empty == true {
                    return recentActivitiesController?.getEmptyLayout()
                } else {
                    return recentActivitiesController?.getLayout()
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

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(1))

        let sectionHeaderItem = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: RootMenuHeaderView.kind.rawValue,
            alignment: .bottom
        )
        sectionHeaderItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)

        section.boundarySupplementaryItems = [sectionHeaderItem]
        return section
    }

    func presentedFromTabBar() {
        recentActivitiesController?.refreshIfNeeded()
    }

    // MARK: - Switch account delegate

    @MainActor func didUpdateCurrentAccountInformations(_ currentAccount: Account) {
        if isViewLoaded {
            reloadTopRows()
        }
    }

    // MARK: - Top scrollable

    func scrollToTop() {
        collectionView?.scrollToTop(animated: true, navigationController: nil)
    }

    // MARK: - State restoration

    var currentSceneMetadata: [AnyHashable: Any] {
        [:]
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
            case .insufficientStorage:
                let cell = collectionView.dequeueReusableCell(type: InsufficientStorageCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.configureCell(with: driveFileManager.drive)
                cell.actionHandler = { [weak self] _ in
                    guard let self else { return }
                    router.presentUpSaleSheet()
                    matomo.track(eventWithCategory: .myKSuiteUpgradeBottomSheet, name: "notEnoughStorageUpgrade")
                }
                cell.closeHandler = { [weak self] _ in
                    guard let self else { return }
                    showInsufficientStorage = false
                    let newViewModel = HomeViewModel(topRows: getTopRows(),
                                                     recentFiles: viewModel.recentFiles,
                                                     isLoading: viewModel.isLoading)
                    reload(newViewModel: newViewModel)
                }
                return cell
            }
        case .recentFiles:
            if let cellType = recentActivitiesController?.listCellType,
               let cell = collectionView.dequeueReusableCell(
                   type: cellType,
                   for: indexPath
               ) as? RecentActivityCollectionViewCell {
                cell.initWithPositionAndShadow()
                if viewModel.isLoading && indexPath.row > viewModel.recentFilesCount - 1 {
                    cell.configureLoading()
                } else {
                    let activity = viewModel.recentFiles[indexPath.row]
                    cell.configureWith(recentActivity: activity)
                    cell.delegate = self
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
                let homeLargeTitleHeaderView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    view: HomeLargeTitleHeaderView.self,
                    for: indexPath
                )
                homeLargeTitleHeaderView.configureForDriveSwitch(
                    accountManager: accountManager,
                    driveFileManager: driveFileManager,
                    presenter: self,
                    selectMode: false
                )
                if !isCompactView {
                    homeLargeTitleHeaderView.isEnabled = false
                    homeLargeTitleHeaderView.text = recentActivitiesController?.title ?? ""
                }
                headerViewHeight = homeLargeTitleHeaderView.frame.height
                return homeLargeTitleHeaderView
            case .recentFiles:
                let headerView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    view: HomeRecentFilesHeaderView.self,
                    for: indexPath
                )
                if isCompactView {
                    headerView.titleLabel.text = recentActivitiesController?.title ?? ""
                } else {
                    headerView.titleLabel.text = ""
                }
                return headerView
            }
        } else if kind == RootMenuHeaderView.kind.rawValue {
            let headerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                view: RootMenuHeaderView.self,
                for: indexPath
            )

            headerView.configureInCollectionView(collectionView, driveFileManager: driveFileManager, presenter: self)
            return headerView
        } else {
            return UICollectionReusableView()
        }
    }
}

// MARK: - UICollectionViewDelegate

extension HomeViewController {
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
                                                   isLoading: true))
                recentActivitiesController.loadNextPage()
            }
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
            let destinationViewController = RecentActivityFilesViewController(
                activities: activities,
                driveFileManager: driveFileManager
            )
            filePresenter.navigationController?.pushViewController(destinationViewController, animated: true)
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
