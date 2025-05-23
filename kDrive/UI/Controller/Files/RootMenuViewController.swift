/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import InfomaniakCore
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

class RootMenuViewController: CustomLargeTitleCollectionViewController, SelectSwitchDriveDelegate {
    let selectMode: Bool

    public typealias MenuDataSource = UICollectionViewDiffableDataSource<RootMenuSection, RootMenuItem>
    public typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<RootMenuSection, RootMenuItem>

    public enum RootMenuSection: Hashable, CaseIterable {
        case main
        case recent

        var title: String {
            switch self {
            case .main: return KDriveResourcesStrings.Localizable.allFilesTitle
            case .recent: return KDriveResourcesStrings.Localizable.buttonRecent
            }
        }
    }

    struct RootMenuItem: Equatable, Hashable {
        var id: Int {
            return destinationFile.id
        }

        let name: String
        let image: UIImage
        let destinationFile: File
        var isFirst = false
        var isLast = false

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(isFirst)
            hasher.combine(isLast)
        }
    }

    private static let baseItems: [RootMenuItem] = [RootMenuItem(name: KDriveResourcesStrings.Localizable.favoritesTitle,
                                                                 image: KDriveResourcesAsset.favorite.image,
                                                                 destinationFile: DriveFileManager.favoriteRootFile),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.lastEditsTitle,
                                                                 image: KDriveResourcesAsset.clock.image,
                                                                 destinationFile: DriveFileManager.lastModificationsRootFile),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
                                                                 image: KDriveResourcesAsset.folderSelect2.image,
                                                                 destinationFile: DriveFileManager.sharedWithMeRootFile),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.mySharesTitle,
                                                                 image: KDriveResourcesAsset.folderSelect.image,
                                                                 destinationFile: DriveFileManager.mySharedRootFile),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.offlineFileTitle,
                                                                 image: KDriveResourcesAsset.availableOffline.image,
                                                                 destinationFile: DriveFileManager.offlineRoot),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.trashTitle,
                                                                 image: KDriveResourcesAsset.delete.image,
                                                                 destinationFile: DriveFileManager.trashRootFile)]

    @LazyInjectService private var accountManager: AccountManageable

    let driveFileManager: DriveFileManager
    private var rootChildrenObservationToken: NotificationToken?
    var rootViewChildren: [File]?
    private lazy var dataSource: MenuDataSource = configureDataSource(for: collectionView)
    let refreshControl = UIRefreshControl()
    var itemsSnapshot: DataSourceSnapshot {
        let userRootFolders = rootViewChildren?.compactMap {
            RootMenuItem(name: $0.formattedLocalizedName(drive: driveFileManager.drive), image: $0.icon, destinationFile: $0)
        } ?? []

        var menuItems = userRootFolders + RootMenuViewController.baseItems
        if !menuItems.isEmpty {
            menuItems[0].isFirst = true
            menuItems[menuItems.count - 1].isLast = true
        }

        var snapshot = DataSourceSnapshot()
        snapshot.appendSections([RootMenuSection.main])
        snapshot.appendItems(menuItems)
        return snapshot
    }

    init(driveFileManager: DriveFileManager, selectMode: Bool) {
        self.driveFileManager = driveFileManager
        self.selectMode = selectMode
        super.init(collectionViewLayout: RootMenuViewController.createListLayout(selectMode: selectMode))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = driveFileManager.drive.name
        navigationItem.rightBarButtonItem = FileListBarButton(type: .search, target: self, action: #selector(presentSearch))

        collectionView.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.List.paddingBottom, right: 0)
        collectionView.refreshControl = refreshControl

        collectionView.register(RootMenuCell.self, forCellWithReuseIdentifier: RootMenuCell.identifier)
        collectionView.register(supplementaryView: HomeLargeTitleHeaderView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(supplementaryView: RootMenuHeaderView.self, forSupplementaryViewOfKind: RootMenuHeaderView.kind)
        collectionView.register(
            supplementaryView: ReusableHeaderView.self,
            forSupplementaryViewOfKind: ReusableHeaderView.kind
        )

        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)

        dataSource = configureDataSource(for: collectionView)
        setItemsSnapshot(for: collectionView)
    }

    func setItemsSnapshot(for: UICollectionView) {
        let rootFileUid = File.uid(driveId: driveFileManager.driveId, fileId: DriveFileManager.constants.rootID)
        guard let root = driveFileManager.database.fetchObject(ofType: File.self, forPrimaryKey: rootFileUid) else {
            return
        }

        let rootChildren = root.children.filter(NSPredicate(
            format: "rawVisibility IN %@",
            [FileVisibility.isPrivateSpace.rawValue, FileVisibility.isTeamSpace.rawValue]
        ))
        rootChildrenObservationToken = rootChildren.observe { [weak self] changes in
            guard let self else { return }
            switch changes {
            case .initial(let children):
                rootViewChildren = Array(AnyRealmCollection(children).filesSorted(by: .nameAZ))
                dataSource.apply(itemsSnapshot, animatingDifferences: false)

            case .update(let children, _, _, _):
                rootViewChildren = Array(AnyRealmCollection(children).filesSorted(by: .nameAZ))
                dataSource.apply(itemsSnapshot, animatingDifferences: true)

            case .error:
                break
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        (tabBarController as? PlusButtonObserver)?.updateCenterButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        saveSceneState()
    }

    @objc func presentSearch() {
        let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager)
        let searchViewController = SearchViewController.instantiateInNavigationController(viewModel: viewModel)
        present(searchViewController, animated: true)
    }

    @objc func forceRefresh() {
        Task {
            try? await driveFileManager.initRoot()
            refreshControl.endRefreshing()
        }
    }

    func configureDataSource(
        for collectionView: UICollectionView
    )
        -> UICollectionViewDiffableDataSource<RootMenuSection, RootMenuItem> {
        dataSource = UICollectionViewDiffableDataSource<RootMenuSection, RootMenuItem>(collectionView: collectionView) {
            collectionView, indexPath, menuItem -> RootMenuCell?
            in
            guard let rootMenuCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: RootMenuCell.identifier,
                for: indexPath
            ) as? RootMenuCell else {
                fatalError("Failed to dequeue cell")
            }

            rootMenuCell.configure(title: menuItem.name, icon: menuItem.image)
            rootMenuCell.initWithPositionAndShadow(isFirst: menuItem.isFirst, isLast: menuItem.isLast)
            return rootMenuCell
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self else { return UICollectionReusableView() }

            switch kind {
            case UICollectionView.elementKindSectionHeader:
                let homeLargeTitleHeaderView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    view: HomeLargeTitleHeaderView.self,
                    for: indexPath
                )

                homeLargeTitleHeaderView.configureForDriveSwitch(
                    accountManager: accountManager,
                    driveFileManager: driveFileManager,
                    presenter: self,
                    selectMode: selectMode
                )

                headerViewHeight = homeLargeTitleHeaderView.frame.height
                return homeLargeTitleHeaderView

            case RootMenuHeaderView.kind.rawValue:
                let headerView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    view: RootMenuHeaderView.self,
                    for: indexPath
                )

                headerView.configureInCollectionView(collectionView, driveFileManager: driveFileManager, presenter: self)
                return headerView

            case ReusableHeaderView.kind.rawValue:
                let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: ReusableHeaderView.kind.rawValue,
                    for: indexPath
                )

                if let reusableHeader = header as? ReusableHeaderView,
                   let sectionIdentifier = dataSource.snapshot().sectionIdentifiers[safe: indexPath.section] {
                    reusableHeader.titleLabel.text = sectionIdentifier.title
                }

                return header

            default:
                fatalError("Unhandled kind \(kind)")
            }
        }

        dataSource.apply(itemsSnapshot, animatingDifferences: false)
        return dataSource
    }

    static func createListLayout(selectMode: Bool) -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .estimated(60))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(60))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                       subitems: [item])

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(0))

        let sectionHeaderItem = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: selectMode ? ReusableHeaderView.kind.rawValue : RootMenuHeaderView.kind
                .rawValue,
            alignment: .top
        )

        if !selectMode {
            sectionHeaderItem.contentInsets = NSDirectionalEdgeInsets(
                top: UIConstants.Padding.none,
                leading: UIConstants.Padding.mediumSmall,
                bottom: UIConstants.Padding.none,
                trailing: UIConstants.Padding.mediumSmall
            )
        }

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: -UIConstants.Padding.small,
            leading: UIConstants.Padding.none,
            bottom: UIConstants.Padding.standard,
            trailing: UIConstants.Padding.none
        )
        section.boundarySupplementaryItems = [sectionHeaderItem]

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.boundarySupplementaryItems = [generateHeaderItem()]
        let layout = UICollectionViewCompositionalLayout(section: section, configuration: configuration)
        return layout
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedRootFile = dataSource.itemIdentifier(for: indexPath)?.destinationFile else { return }

        let destinationViewModel: FileListViewModel
        switch selectedRootFile.id {
        case DriveFileManager.favoriteRootFile.id:
            destinationViewModel = FavoritesViewModel(driveFileManager: driveFileManager)
        case DriveFileManager.lastModificationsRootFile.id:
            destinationViewModel = LastModificationsViewModel(driveFileManager: driveFileManager)
        case DriveFileManager.sharedWithMeRootFile.id:
            let sharedWithMeDriveFileManager = driveFileManager.instanceWith(context: .sharedWithMe)
            destinationViewModel = SharedWithMeViewModel(driveFileManager: sharedWithMeDriveFileManager)
        case DriveFileManager.offlineRoot.id:
            destinationViewModel = OfflineFilesViewModel(driveFileManager: driveFileManager)
        case DriveFileManager.trashRootFile.id:
            destinationViewModel = TrashListViewModel(driveFileManager: driveFileManager)
        case DriveFileManager.mySharedRootFile.id:
            destinationViewModel = MySharesViewModel(driveFileManager: driveFileManager)
        default:
            destinationViewModel = ConcreteFileListViewModel(
                driveFileManager: driveFileManager,
                currentDirectory: selectedRootFile,
                rightBarButtons: [.search]
            )
        }

        let destinationViewController = FileListViewController(viewModel: destinationViewModel)
        destinationViewModel.onDismissViewController = { [weak destinationViewController] in
            destinationViewController?.dismiss(animated: true)
        }

        navigationController?.pushViewController(destinationViewController, animated: true)
    }

    // MARK: - State restoration

    var currentSceneMetadata: [AnyHashable: Any] {
        [:]
    }
}
