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

class SidebarViewController: CustomLargeTitleCollectionViewController, SelectSwitchDriveDelegate {
    private typealias MenuDataSource = UICollectionViewDiffableDataSource<RootMenuSection, RootMenuItem>
    private typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<RootMenuSection, RootMenuItem>
    private var selectedIndexPath: IndexPath?

    private enum RootMenuSection {
        case main
        case first
        case second
        case third
    }

    private struct RootMenuItem: Equatable, Hashable {
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

    private static var baseItems: [RootMenuItem] = [RootMenuItem(name: KDriveResourcesStrings.Localizable.homeTitle,
                                                                 image: KDriveResourcesAsset.house.image,
                                                                 destinationFile: DriveFileManager.favoriteRootFile,
                                                                 priority: 3),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.allPictures,
                                                                 image: KDriveResourcesAsset.mediaInline.image,
                                                                 destinationFile: DriveFileManager.trashRootFile,
                                                                 priority: 2),
                                                    RootMenuItem(
                                                        name: KDriveResourcesStrings.Localizable.favoritesTitle,
                                                        image: KDriveResourcesAsset.favorite.image,
                                                        destinationFile: DriveFileManager.favoriteRootFile
                                                    ),
                                                    RootMenuItem(
                                                        name: KDriveResourcesStrings.Localizable
                                                            .lastEditsTitle,
                                                        image: KDriveResourcesAsset.clock.image,
                                                        destinationFile: DriveFileManager
                                                            .lastModificationsRootFile
                                                    ),
                                                    RootMenuItem(
                                                        name: KDriveResourcesStrings.Localizable
                                                            .offlineFileTitle,
                                                        image: KDriveResourcesAsset.availableOffline
                                                            .image,
                                                        destinationFile: DriveFileManager.offlineRoot
                                                    )]

    private static var secondSectionItems: [RootMenuItem] = [
        RootMenuItem(name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
                     image: KDriveResourcesAsset.folderSelect2.image,
                     destinationFile: DriveFileManager.sharedWithMeRootFile),
        RootMenuItem(name: KDriveResourcesStrings.Localizable.mySharesTitle,
                     image: KDriveResourcesAsset.folderSelect.image,
                     destinationFile: DriveFileManager.mySharedRootFile)
    ]

    private static var thirdSectionItems: [RootMenuItem] = [RootMenuItem(name: KDriveResourcesStrings.Localizable.trashTitle,
                                                                         image: KDriveResourcesAsset.delete.image,
                                                                         destinationFile: DriveFileManager.trashRootFile)]

    private static let compactModeItems: [RootMenuItem] = [RootMenuItem(name: KDriveResourcesStrings.Localizable.favoritesTitle,
                                                                        image: KDriveResourcesAsset.favorite.image,
                                                                        destinationFile: DriveFileManager.favoriteRootFile),
                                                           RootMenuItem(name: KDriveResourcesStrings.Localizable.lastEditsTitle,
                                                                        image: KDriveResourcesAsset.clock.image,
                                                                        destinationFile: DriveFileManager
                                                                            .lastModificationsRootFile),
                                                           RootMenuItem(
                                                               name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
                                                               image: KDriveResourcesAsset.folderSelect2.image,
                                                               destinationFile: DriveFileManager.sharedWithMeRootFile
                                                           ),
                                                           RootMenuItem(name: KDriveResourcesStrings.Localizable.mySharesTitle,
                                                                        image: KDriveResourcesAsset.folderSelect.image,
                                                                        destinationFile: DriveFileManager.mySharedRootFile),
                                                           RootMenuItem(name: KDriveResourcesStrings.Localizable.offlineFileTitle,
                                                                        image: KDriveResourcesAsset.availableOffline.image,
                                                                        destinationFile: DriveFileManager.offlineRoot),
                                                           RootMenuItem(name: KDriveResourcesStrings.Localizable.trashTitle,
                                                                        image: KDriveResourcesAsset.delete.image,
                                                                        destinationFile: DriveFileManager.trashRootFile)]

    weak var delegate: SidebarViewControllerDelegate?
    @LazyInjectService private var accountManager: AccountManageable
    let driveFileManager: DriveFileManager
    private var rootChildrenObservationToken: NotificationToken?
    private var rootViewChildren: [File]?
    private var dataSource: MenuDataSource?
    private let refreshControl = UIRefreshControl()

    private var displayedSnapshot = DataSourceSnapshot()

    private func getItemsSnapshot(horizontalSizeClass: UIUserInterfaceSizeClass) -> DataSourceSnapshot {
        var snapshot = DataSourceSnapshot()
        let userRootFolders = rootViewChildren?.compactMap {
            RootMenuItem(
                name: $0.formattedLocalizedName(drive: driveFileManager.drive),
                image: $0.icon,
                destinationFile: $0,
                priority: 1
            )
        } ?? []

        if horizontalSizeClass == .regular {
            let firstSectionItems = SidebarViewController.baseItems
            let secondSectionItems = userRootFolders + SidebarViewController.secondSectionItems
            let thirdSectionItems = SidebarViewController.thirdSectionItems
            var sectionsItems = [firstSectionItems, secondSectionItems, thirdSectionItems]
            let sections = [RootMenuSection.first, RootMenuSection.second, RootMenuSection.third]

            for i in 0 ... sectionsItems.count - 1 {
                if !sections.isEmpty {
                    sectionsItems[i][0].isFirst = true
                    sectionsItems[i][sectionsItems[i].count - 1].isLast = true

                    snapshot.appendSections([sections[i]])
                    snapshot.appendItems(sectionsItems[i], toSection: sections[i])
                }
            }
        } else {
            var menuItems = userRootFolders + SidebarViewController.compactModeItems
            if !menuItems.isEmpty {
                menuItems[0].isFirst = true
                menuItems[menuItems.count - 1].isLast = true
            }

            snapshot.appendSections([RootMenuSection.main])
            snapshot.appendItems(menuItems)
        }
        return snapshot
    }

    init(driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
        super.init(collectionViewLayout: SidebarViewController.createListLayout())
    }

    @available(*, unavailable)
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setDisplayedSnapshot()
        setupViewForCurrentSizeClass()
    }

    func setDisplayedSnapshot() {
        @InjectService var appRouter: AppNavigable
        guard let rootViewController = appRouter.rootViewController else {
            return
        }

        let rootHorizontalSizeClass = rootViewController.traitCollection.horizontalSizeClass
        displayedSnapshot = getItemsSnapshot(horizontalSizeClass: rootHorizontalSizeClass)
        setupViewForCurrentSizeClass()
        dataSource?.apply(displayedSnapshot, animatingDifferences: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setDisplayedSnapshot()
        setupViewForCurrentSizeClass()
        configureDataSource()
    }

    private func setupViewForCurrentSizeClass() {
        @InjectService var appRouter: AppNavigable
        guard let rootViewController = appRouter.rootViewController else {
            return
        }

        let rootHorizontalSizeClass = rootViewController.traitCollection.horizontalSizeClass
        let buttonAdd = ImageButton()
        var avatar = UIImage()

        buttonAdd.setImage(KDriveResourcesAsset.plus.image, for: .normal)
        buttonAdd.tintColor = .white
        buttonAdd.imageWidth = 18
        buttonAdd.imageHeight = 18
        buttonAdd.imageSpacing = 20
        buttonAdd.setTitle(KDriveResourcesStrings.Localizable.buttonAdd, for: .normal)
        buttonAdd.backgroundColor = KDriveResourcesAsset.infomaniakColor.color
        buttonAdd.setTitleColor(.white, for: .normal)
        buttonAdd.layer.cornerRadius = 10
        buttonAdd.translatesAutoresizingMaskIntoConstraints = false

        if rootHorizontalSizeClass == .regular {
            accountManager.currentAccount?.user?.getAvatar(size: CGSize(width: 512, height: 512)) { image in
                avatar = SidebarViewController.generateProfileTabImages(image: image)
                let buttonMenu = UIBarButtonItem(
                    image: avatar,
                    style: .plain,
                    target: self,
                    action: #selector(self.buttonMenuClicked(_:))
                )
                self.navigationItem.rightBarButtonItem = buttonMenu
            }
            collectionView.addSubview(buttonAdd)

            buttonAdd.addTarget(self, action: #selector(buttonAddClicked), for: .touchUpInside)

            NSLayoutConstraint.activate([
                buttonAdd.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 48),
                buttonAdd.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
                buttonAdd.heightAnchor.constraint(equalToConstant: 48),
                buttonAdd.widthAnchor.constraint(equalToConstant: 200)
            ])

        } else {
            navigationItem.rightBarButtonItem = FileListBarButton(type: .search, target: self, action: #selector(presentSearch))
            for subview in collectionView.subviews {
                if subview is UIButton {
                    subview.removeFromSuperview()
                }
            }
        }

        navigationItem.title = driveFileManager.drive.name

        collectionView.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.List.paddingBottom, right: 0)
        collectionView.refreshControl = refreshControl

        collectionView.register(RootMenuCell.self, forCellWithReuseIdentifier: RootMenuCell.identifier)
        collectionView.register(supplementaryView: HomeLargeTitleHeaderView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(supplementaryView: RootMenuHeaderView.self, forSupplementaryViewOfKind: RootMenuHeaderView.kind)

        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)

        let rootFileUid = File.uid(driveId: driveFileManager.drive.id, fileId: DriveFileManager.constants.rootID)
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
                dataSource?.apply(displayedSnapshot, animatingDifferences: false)
            case .update(let children, _, _, _):
                rootViewChildren = Array(AnyRealmCollection(children).filesSorted(by: .nameAZ))
                dataSource?.apply(displayedSnapshot, animatingDifferences: true)
            case .error:
                break
            }
        }
    }

    private static func generateProfileTabImages(image: UIImage) -> (UIImage) {
        let iconSize = 28.0

        let image = image
            .resize(size: CGSize(width: iconSize, height: iconSize))
            .maskImageWithRoundedRect(cornerRadius: CGFloat(iconSize / 2), borderWidth: 0, borderColor: nil)
            .withRenderingMode(.alwaysOriginal)
        return image
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

        dataSource?.apply(displayedSnapshot, animatingDifferences: false)
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
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0)

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.boundarySupplementaryItems = [generateHeaderItem()]
        let layout = UICollectionViewCompositionalLayout(section: section, configuration: configuration)
        return layout
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
        if indexPath != selectedIndexPath {
            let userRootFolders = rootViewChildren?.compactMap {
                RootMenuItem(name: $0.formattedLocalizedName(drive: driveFileManager.drive), image: $0.icon, destinationFile: $0)
            } ?? []
            switch displayedSnapshot.sectionIdentifiers[indexPath.section] {
            case .first:
                let menuItems = SidebarViewController.baseItems
                let selectedItemName = menuItems[indexPath.row].name
                delegate?.didSelectItem(destinationViewModel: destinationViewModel, name: selectedItemName)
            case .second:
                let length = (SidebarViewController.baseItems).count
                let menuItems = (SidebarViewController.baseItems + userRootFolders + SidebarViewController
                    .secondSectionItems)
                let selectedItemName = menuItems[indexPath.row + length].name
                delegate?.didSelectItem(destinationViewModel: destinationViewModel, name: selectedItemName)
            case .third:
                let length = (SidebarViewController.baseItems + userRootFolders + SidebarViewController
                    .secondSectionItems).count
                let menuItems = (SidebarViewController.baseItems + userRootFolders + SidebarViewController
                    .secondSectionItems + SidebarViewController.thirdSectionItems)
                let selectedItemName = menuItems[indexPath.row + length].name
                delegate?.didSelectItem(destinationViewModel: destinationViewModel, name: selectedItemName)
            case .main:
                let destinationViewController = FileListViewController(viewModel: destinationViewModel)
                destinationViewModel.onDismissViewController = { [weak destinationViewController] in
                    destinationViewController?.dismiss(animated: true)
                }

                navigationController?.pushViewController(destinationViewController, animated: true)
            }
        }

        selectedIndexPath = indexPath
    }

    @objc func buttonAddClicked() {
        let currentDriveFileManager = driveFileManager
        let currentDirectory = (splitViewController?.viewController(for: .secondary) as? UINavigationController)?
            .topViewController as? FileListViewController
        let currentDirectoryOrRoot = currentDirectory?.viewModel.currentDirectory ?? driveFileManager.getCachedMyFilesRoot()
        guard let currentDirectoryOrRoot else {
            return
        }
        let floatingPanelViewController = AdaptiveDriveFloatingPanelController()

        let plusButtonFloatingPanel = PlusButtonFloatingPanelViewController(
            driveFileManager: currentDriveFileManager,
            folder: currentDirectoryOrRoot
        )

        floatingPanelViewController.isRemovalInteractionEnabled = true
        floatingPanelViewController.delegate = plusButtonFloatingPanel

        floatingPanelViewController.set(contentViewController: plusButtonFloatingPanel)
        floatingPanelViewController.trackAndObserve(scrollView: plusButtonFloatingPanel.tableView)
        present(floatingPanelViewController, animated: true)
    }

    @objc func buttonMenuClicked(_ sender: UIBarButtonItem) {
        if selectedIndexPath != [-1, -1] {
            selectedIndexPath = [-1, -1]
            delegate?.didSelectItem(
                destinationViewModel: MySharesViewModel(driveFileManager: driveFileManager),
                name: KDriveResourcesStrings.Localizable.menuTitle
            )
        }
    }
}

protocol SidebarViewControllerDelegate: AnyObject {
    func didSelectItem(destinationViewModel: FileListViewModel, name: String)
}
