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
import InfomaniakCoreUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

class RootMenuViewController: CustomLargeTitleCollectionViewController, SelectSwitchDriveDelegate {
    private typealias MenuDataSource = UICollectionViewDiffableDataSource<RootMenuSection, RootMenuItem>
    private typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<RootMenuSection, RootMenuItem>

    private enum RootMenuSection {
        case main
    }

    private struct RootMenuItem: Equatable, Hashable {
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
    private var rootViewChildren: [File]?
    private var dataSource: MenuDataSource?
    private let refreshControl = UIRefreshControl()

    private var itemsSnapshot: DataSourceSnapshot {
        let userRootFolders = rootViewChildren?.compactMap {
            RootMenuItem(name: $0.formattedLocalizedName(), image: $0.icon, destinationFile: $0)
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

    init(driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
        super.init(collectionViewLayout: RootMenuViewController.createListLayout())
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
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)
        collectionView.refreshControl = refreshControl

        collectionView.register(RootMenuCell.self, forCellWithReuseIdentifier: RootMenuCell.identifier)
        collectionView.register(supplementaryView: HomeLargeTitleHeaderView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(supplementaryView: RootMenuHeaderView.self, forSupplementaryViewOfKind: RootMenuHeaderView.kind)

        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)

        configureDataSource()

        let rootFileUid = File.uid(driveId: driveFileManager.drive.id, fileId: DriveFileManager.constants.rootID)
        guard let root = driveFileManager.fetchObject(ofType: File.self, forPrimaryKey: rootFileUid),
              !root.isInvalidated else {
            return
        }

        let rootChildren = root.children
        rootChildrenObservationToken = rootChildren.observe { [weak self] changes in
            guard let self else { return }
            switch changes {
            case .initial(let children):
                rootViewChildren = Array(AnyRealmCollection(children).filesSorted(by: .nameAZ))
                dataSource?.apply(itemsSnapshot, animatingDifferences: false)
            case .update(let children, _, _, _):
                rootViewChildren = Array(AnyRealmCollection(children).filesSorted(by: .nameAZ))
                dataSource?.apply(itemsSnapshot, animatingDifferences: true)
            case .error:
                break
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        (tabBarController as? PlusButtonObserver)?.updateCenterButton()
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

    func configureDataSource() {
        dataSource = MenuDataSource(collectionView: collectionView) { collectionView, indexPath, menuItem -> RootMenuCell? in
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

        dataSource?.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
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
                    presenter: self
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
            default:
                fatalError("Unhandled kind \(kind)")
            }
        }

        dataSource?.apply(itemsSnapshot, animatingDifferences: false)
    }

    static func createListLayout() -> UICollectionViewLayout {
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
            elementKind: RootMenuHeaderView.kind.rawValue,
            alignment: .top
        )
        sectionHeaderItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        sectionHeaderItem.pinToVisibleBounds = true

        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = [sectionHeaderItem]

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.boundarySupplementaryItems = [generateHeaderItem()]
        let layout = UICollectionViewCompositionalLayout(section: section, configuration: configuration)
        return layout
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedRootFile = dataSource?.itemIdentifier(for: indexPath)?.destinationFile else { return }

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
                currentDirectory: selectedRootFile
            )
        }

        let destinationViewController = FileListViewController.instantiate(viewModel: destinationViewModel)
        navigationController?.pushViewController(destinationViewController, animated: true)
    }
}
