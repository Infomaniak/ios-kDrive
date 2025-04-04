//
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

import InfomaniakCore
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

class LocationFolderViewController: CustomLargeTitleCollectionViewController, SelectSwitchDriveDelegate {
    private typealias LocationDataSource = UICollectionViewDiffableDataSource<LocationSection, LocationItem>
    private typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<LocationSection, LocationItem>
    private var selectedIndexPath: IndexPath?

    private enum LocationSection {
        case recent
        case main
    }

    private struct LocationItem: Equatable, Hashable {
        var id: Int {
            return destinationFile.id
        }

        let name: String
        var image: UIImage
        let destinationFile: File
        var isFirst = false
        var isLast = false
        var priority = 0

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(isFirst)
            hasher.combine(isLast)
        }
    }

    private static let recentItems: [LocationItem] = [LocationItem(name: KDriveResourcesStrings.Localizable.lastEditsTitle,
                                                                   image: KDriveResourcesAsset.clock.image,
                                                                   destinationFile: DriveFileManager
                                                                       .lastModificationsRootFile)]

    private static let mainItems: [LocationItem] = [LocationItem(name: KDriveResourcesStrings.Localizable.favoritesTitle,
                                                                 image: KDriveResourcesAsset.favorite.image,
                                                                 destinationFile: DriveFileManager.favoriteRootFile),
                                                    LocationItem(name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
                                                                 image: KDriveResourcesAsset.folderSelect2.image,
                                                                 destinationFile: DriveFileManager.sharedWithMeRootFile),
                                                    LocationItem(name: KDriveResourcesStrings.Localizable.mySharesTitle,
                                                                 image: KDriveResourcesAsset.folderSelect.image,
                                                                 destinationFile: DriveFileManager.mySharedRootFile)]

    @LazyInjectService private var accountManager: AccountManageable

    let driveFileManager: DriveFileManager
    private var rootChildrenObservationToken: NotificationToken?
    private var rootViewChildren: [File]?
    private var dataSource: LocationDataSource?
    private let refreshControl = UIRefreshControl()
    private var itemsSnapshot: DataSourceSnapshot {
        var snapshot = DataSourceSnapshot()
        let userRootFolders = rootViewChildren?.compactMap {
            LocationItem(name: $0.formattedLocalizedName(drive: driveFileManager.drive), image: $0.icon, destinationFile: $0)
        } ?? []

        let firstSectionItems = LocationFolderViewController.recentItems
        let secondSectionItems = userRootFolders + LocationFolderViewController.mainItems
        let sections = [LocationSection.recent, LocationSection.main]
        var sectionItems = [firstSectionItems, secondSectionItems]

        for i in 0 ... sectionItems.count - 1 {
            if !sectionItems[i].isEmpty {
                sectionItems[i][0].isFirst = true
                sectionItems[i][sectionItems[i].count - 1].isLast = true

                snapshot.appendSections([sections[i]])
                snapshot.appendItems(sectionItems[i], toSection: sections[i])
            }
        }
        return snapshot
    }

    init(driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
        super.init(collectionViewLayout: LocationFolderViewController.createListLayout())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = driveFileManager.drive.name
        collectionView.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.List.paddingBottom, right: 0)
        collectionView.refreshControl = refreshControl

        collectionView.register(RootMenuCell.self, forCellWithReuseIdentifier: RootMenuCell.identifier)
        collectionView.register(supplementaryView: HomeLargeTitleHeaderView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(supplementaryView: RootMenuHeaderView.self, forSupplementaryViewOfKind: RootMenuHeaderView.kind)

        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)

        configureDataSource()

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
                dataSource?.apply(itemsSnapshot, animatingDifferences: false)
            case .update(let children, _, _, _):
                rootViewChildren = Array(AnyRealmCollection(children).filesSorted(by: .nameAZ))
                dataSource?.apply(itemsSnapshot, animatingDifferences: true)
            case .error:
                break
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        saveSceneState()
    }

    @objc func forceRefresh() {
        Task {
            try? await driveFileManager.initRoot()
            refreshControl.endRefreshing()
        }
    }

    func configureDataSource() {
        dataSource = LocationDataSource(collectionView: collectionView) { collectionView, indexPath, menuItem -> RootMenuCell?
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
        section.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 16, bottom: 24, trailing: 16)
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
        case DriveFileManager.sharedWithMeRootFile.id:
            let sharedWithMeDriveFileManager = driveFileManager.instanceWith(context: .sharedWithMe)
            destinationViewModel = SharedWithMeViewModel(driveFileManager: sharedWithMeDriveFileManager)
        case DriveFileManager.mySharedRootFile.id:
            destinationViewModel = MySharesViewModel(driveFileManager: driveFileManager)
        case DriveFileManager.lastModificationsRootFile.id:
            destinationViewModel = LastModificationsViewModel(driveFileManager: driveFileManager)
        default:
            destinationViewModel = ConcreteFileListViewModel(
                driveFileManager: driveFileManager,
                currentDirectory: selectedRootFile
            )
        }

        let destinationViewController = FileListViewController(viewModel: destinationViewModel)
        destinationViewModel.onDismissViewController = { [weak destinationViewController] in
            destinationViewController?.dismiss(animated: true)
        }

        navigationController?.pushViewController(destinationViewController, animated: true)
    }
}
