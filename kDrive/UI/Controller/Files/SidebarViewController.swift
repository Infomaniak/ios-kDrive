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
import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

class SidebarViewController: CustomLargeTitleCollectionViewController, SelectSwitchDriveDelegate {
    @LazyInjectService private var accountManager: AccountManageable
    public typealias MenuDataSource = UICollectionViewDiffableDataSource<RootMenuSection, RootMenuItem>
    public typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<RootMenuSection, RootMenuItem>
    private var selectedIndexPath: IndexPath?
    private let menuIndexPath: IndexPath = [-1, -1]
    private var plusButtonTableViewController: UITableViewController?
    let selectMode: Bool

    private var isMenuIndexPathSelected: Bool {
        if selectedIndexPath != menuIndexPath {
            selectedIndexPath = menuIndexPath
            return false
        }

        return true
    }

    public enum RootMenuSection {
        case main
        case first
        case second
        case third

        var title: String {
            switch self {
            case .main: return KDriveResourcesStrings.Localizable.allFilesTitle
            case .first: return KDriveResourcesStrings.Localizable.recentTitle
            default: return ""
            }
        }
    }

    public struct RootMenuItem: Equatable, Hashable {
        var id: Int {
            return destination.hashValue
        }

        let name: String
        var image: UIImage
        let destination: RootMenuDestination
        var isFirst = false
        var isLast = false
        var priority = 0

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(isFirst)
            hasher.combine(isLast)
        }
    }

    enum RootMenuDestination: Equatable, Hashable {
        case home
        case photoList
        case file(File)

        func hash(into hasher: inout Hasher) {
            switch self {
            case .home:
                hasher.combine("home")
            case .photoList:
                hasher.combine("photolist")
            case .file(let file):
                hasher.combine("file")
                hasher.combine(file.uid)
                hasher.combine(file.name)
            }
        }

        static func == (lhs: RootMenuDestination, rhs: RootMenuDestination) -> Bool {
            switch (lhs, rhs) {
            case (.home, .home):
                return true
            case (.photoList, .photoList):
                return true
            case (.file(let lhsFile), .file(let rhsFile)):
                return lhsFile.uid == rhsFile.uid && lhsFile.name == rhsFile.name
            default:
                return false
            }
        }
    }

    private static var baseItems: [RootMenuItem] = [RootMenuItem(name: KDriveResourcesStrings.Localizable.homeTitle,
                                                                 image: KDriveResourcesAsset.house.image,
                                                                 destination: .home,
                                                                 priority: 3),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.allPictures,
                                                                 image: KDriveResourcesAsset.mediaInline.image,
                                                                 destination: .photoList,
                                                                 priority: 2),
                                                    RootMenuItem(
                                                        name: KDriveResourcesStrings.Localizable.favoritesTitle,
                                                        image: KDriveResourcesAsset.favorite.image,
                                                        destination: .file(DriveFileManager.favoriteRootFile)
                                                    ),
                                                    RootMenuItem(
                                                        name: KDriveResourcesStrings.Localizable.lastEditsTitle,
                                                        image: KDriveResourcesAsset.clock.image,
                                                        destination: .file(DriveFileManager.lastModificationsRootFile)
                                                    ),
                                                    RootMenuItem(
                                                        name: KDriveResourcesStrings.Localizable.offlineFileTitle,
                                                        image: KDriveResourcesAsset.availableOffline.image,
                                                        destination: .file(DriveFileManager.offlineRoot)
                                                    )]

    private static var sharedItems: [RootMenuItem] = [
        RootMenuItem(name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
                     image: KDriveResourcesAsset.folderSelect2.image,
                     destination: .file(DriveFileManager.sharedWithMeRootFile)),
        RootMenuItem(name: KDriveResourcesStrings.Localizable.mySharesTitle,
                     image: KDriveResourcesAsset.folderSelect.image,
                     destination: .file(DriveFileManager.mySharedRootFile))
    ]

    private static var trashItem: [RootMenuItem] = [RootMenuItem(name: KDriveResourcesStrings.Localizable.trashTitle,
                                                                 image: KDriveResourcesAsset.delete.image,
                                                                 destination: .file(DriveFileManager.trashRootFile))]

    private static let compactModeItems: [RootMenuItem] = [RootMenuItem(name: KDriveResourcesStrings.Localizable.favoritesTitle,
                                                                        image: KDriveResourcesAsset.favorite.image,
                                                                        destination: .file(DriveFileManager.favoriteRootFile)),
                                                           RootMenuItem(name: KDriveResourcesStrings.Localizable.lastEditsTitle,
                                                                        image: KDriveResourcesAsset.clock.image,
                                                                        destination: .file(DriveFileManager
                                                                            .lastModificationsRootFile)),
                                                           RootMenuItem(
                                                               name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
                                                               image: KDriveResourcesAsset.folderSelect2.image,
                                                               destination: .file(DriveFileManager.sharedWithMeRootFile)
                                                           ),
                                                           RootMenuItem(name: KDriveResourcesStrings.Localizable.mySharesTitle,
                                                                        image: KDriveResourcesAsset.folderSelect.image,
                                                                        destination: .file(DriveFileManager.mySharedRootFile)),
                                                           RootMenuItem(name: KDriveResourcesStrings.Localizable.offlineFileTitle,
                                                                        image: KDriveResourcesAsset.availableOffline.image,
                                                                        destination: .file(DriveFileManager.offlineRoot)),
                                                           RootMenuItem(name: KDriveResourcesStrings.Localizable.trashTitle,
                                                                        image: KDriveResourcesAsset.delete.image,
                                                                        destination: .file(DriveFileManager.trashRootFile))]

    weak var delegate: SidebarViewControllerDelegate?

    let driveFileManager: DriveFileManager
    private var rootChildrenObservationToken: NotificationToken?
    public var rootViewChildren: [File]?
    private lazy var dataSource: MenuDataSource = configureDataSource(for: collectionView)
    private let refreshControl = UIRefreshControl()

    private lazy var addButton: UIButton = {
        var imageButtonConfiguration = UIButton.Configuration.filled()
        imageButtonConfiguration.image = UIImage(
            systemName: "plus",
            withConfiguration: UIImage.SymbolConfiguration(font: TextStyle.header3.font)
        )
        imageButtonConfiguration.imagePlacement = .leading
        imageButtonConfiguration.imagePadding = UIConstants.Padding.small
        imageButtonConfiguration.background.cornerRadius = UIConstants.Button.cornerRadius
        var container = AttributeContainer()
        container.font = TextStyle.header3.font
        imageButtonConfiguration.attributedTitle = AttributedString(
            KDriveResourcesStrings.Localizable.buttonAdd,
            attributes: container
        )

        let addButton = UIButton(configuration: imageButtonConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.buttonAddClicked()
        })
        addButton.translatesAutoresizingMaskIntoConstraints = false
        return addButton
    }()

    var itemsSnapshot: DataSourceSnapshot {
        getItemsSnapshot(isCompactView: isCompactView)
    }

    private func getItemsSnapshot(isCompactView: Bool) -> DataSourceSnapshot {
        let userRootFolders = rootViewChildren?.compactMap {
            RootMenuItem(
                name: $0.formattedLocalizedName,
                image: $0.icon,
                destination: .file($0),
                priority: 1
            )
        } ?? []

        if !isCompactView {
            return snapshotForCompactView(userRootFolders: userRootFolders)
        } else {
            return snapshotForLargeView(userRootFolders: userRootFolders)
        }
    }

    private func snapshotForCompactView(userRootFolders: [SidebarViewController.RootMenuItem]) -> DataSourceSnapshot {
        var snapshot = DataSourceSnapshot()
        let firstSectionItems = SidebarViewController.baseItems
        let secondSectionItems = userRootFolders + SidebarViewController.sharedItems
        let thirdSectionItems = SidebarViewController.trashItem
        let sectionsItems = [firstSectionItems, secondSectionItems, thirdSectionItems]
        let sections = [RootMenuSection.first, RootMenuSection.second, RootMenuSection.third]

        for i in 0 ... sectionsItems.count - 1 {
            if !sections.isEmpty {
                var sectionItems = sectionsItems[i]
                let section = sections[i]
                sectionItems[0].isFirst = true
                sectionItems[sectionItems.count - 1].isLast = true

                snapshot.appendSections([section])
                snapshot.appendItems(sectionItems, toSection: section)
            }
        }
        return snapshot
    }

    private func snapshotForLargeView(userRootFolders: [SidebarViewController.RootMenuItem]) -> DataSourceSnapshot {
        var snapshot = DataSourceSnapshot()
        var menuItems = userRootFolders + SidebarViewController.compactModeItems
        if !menuItems.isEmpty {
            menuItems[0].isFirst = true
            menuItems[menuItems.count - 1].isLast = true
        }

        snapshot.appendSections([RootMenuSection.main])
        snapshot.appendItems(menuItems)
        return snapshot
    }

    init(driveFileManager: DriveFileManager, selectMode: Bool, isCompactView: Bool) {
        self.driveFileManager = driveFileManager
        self.selectMode = selectMode
        super.init(collectionViewLayout: SidebarViewController.createListLayout(
            selectMode: selectMode,
            isCompactView: isCompactView
        ))
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
        collectionView.register(
            supplementaryView: ReusableHeaderView.self,
            forSupplementaryViewOfKind: ReusableHeaderView.kind
        )

        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)

        dataSource = configureDataSource(for: collectionView)
        setItemsSnapshot(for: collectionView)

        guard !selectMode else { return }
        if !isCompactView {
            accountManager.currentAccount?.user?.getAvatar(size: CGSize(width: 512, height: 512)) { image in
                let avatar = SidebarViewController.generateProfileTabImages(image: image)
                let buttonMenu = UIBarButtonItem(image: avatar, primaryAction: UIAction { [weak self] _ in
                    self?.buttonMenuClicked()
                })
                self.navigationItem.rightBarButtonItem = buttonMenu
            }

            collectionView.addSubview(addButton)

            NSLayoutConstraint.activate([
                addButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
                addButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
                addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
                addButton.heightAnchor.constraint(equalToConstant: 54),
                addButton.widthAnchor.constraint(lessThanOrEqualToConstant: 500)
            ])
        } else {
            navigationItem.rightBarButtonItem = FileListBarButton(
                type: .search,
                target: self,
                action: #selector(presentSearch)
            )
            for subview in collectionView.subviews {
                if subview is UIButton {
                    subview.removeFromSuperview()
                }
            }
        }
    }

    private static func generateProfileTabImages(image: UIImage) -> (UIImage) {
        let iconSize = UIConstants.Button.profileImageSize

        let image = image
            .resize(size: CGSize(width: iconSize, height: iconSize))
            .maskImageWithRoundedRect(cornerRadius: CGFloat(iconSize / 2), borderWidth: 0, borderColor: nil)
            .withRenderingMode(.alwaysOriginal)
        return image
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

    func configureDataSource(for collectionView: UICollectionView)
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
            rootMenuCell.focusEffect = nil
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
                    addLeadingConstraint: !isCompactView,
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

    static func createListLayout(selectMode: Bool, isCompactView: Bool) -> UICollectionViewLayout {
        let sectionProvider: UICollectionViewCompositionalLayoutSectionProvider = { sectionIndex, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .estimated(60))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .estimated(60))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                           subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: -UIConstants.Padding.small,
                leading: UIConstants.Padding.none,
                bottom: UIConstants.Padding.standard,
                trailing: UIConstants.Padding.none
            )

            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                    heightDimension: .estimated(0))

            if sectionIndex == 0 && !selectMode {
                let sectionHeaderItem = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: RootMenuHeaderView.kind.rawValue,
                    alignment: .top
                )

                sectionHeaderItem.contentInsets = NSDirectionalEdgeInsets(
                    top: UIConstants.Padding.none,
                    leading: UIConstants.Padding.mediumSmall,
                    bottom: UIConstants.Padding.none,
                    trailing: UIConstants.Padding.mediumSmall
                )

                section.boundarySupplementaryItems = [sectionHeaderItem]
            }

            if selectMode {
                let sectionHeaderItem = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: ReusableHeaderView.kind.rawValue,
                    alignment: .top
                )

                section.boundarySupplementaryItems = [sectionHeaderItem]
            }

            return section
        }

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration
            .boundarySupplementaryItems = [generateHeaderItem(leading: isCompactView ? UIConstants.Padding.mediumSmall : 0)]
        let layout = UICollectionViewCompositionalLayout(sectionProvider: sectionProvider, configuration: configuration)
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
        guard let destination = dataSource.itemIdentifier(for: indexPath)?.destination else { return }

        if isCompactView {
            guard case .file(let selectedRootFile) = destination else { return }
            let destinationViewModel = getViewModelForRootFile(selectedRootFile)
            let destinationViewController = FileListViewController(viewModel: destinationViewModel)
            destinationViewModel.onDismissViewController = { [weak destinationViewController] in
                destinationViewController?.dismiss(animated: true)
            }

            navigationController?.pushViewController(destinationViewController, animated: true)
        } else if selectedIndexPath != indexPath {
            switch destination {
            case .home:
                delegate?.didSelectItem(destination: .home)
            case .photoList:
                delegate?.didSelectItem(destination: .photoList)
            case .file(let selectedRootFile):
                let destinationViewModel = getViewModelForRootFile(selectedRootFile)
                delegate?.didSelectItem(destination: .file(destinationViewModel))
            }

            selectedIndexPath = indexPath
        }
    }

    func getViewModelForRootFile(_ rootFile: File) -> FileListViewModel {
        let destinationViewModel: FileListViewModel
        switch rootFile.id {
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
                currentDirectory: rootFile,
                rightBarButtons: [.search]
            )
        }

        return destinationViewModel
    }

    func buttonAddClicked() {
        #if !ISEXTENSION
        let currentDriveFileManager = driveFileManager
        let currentDirectory = (splitViewController?.viewController(for: .secondary) as? UINavigationController)?
            .topViewController as? FileListViewController
        let currentDirectoryOrRoot = currentDirectory?.viewModel.currentDirectory ?? driveFileManager.getCachedMyFilesRoot()
        guard let currentDirectoryOrRoot else {
            return
        }

        let plusButtonFloatingPanel = PlusButtonFloatingPanelViewController(
            driveFileManager: currentDriveFileManager,
            folder: currentDirectoryOrRoot
        )
        plusButtonTableViewController = plusButtonFloatingPanel

        plusButtonFloatingPanel.modalPresentationStyle = .popover
        plusButtonFloatingPanel.popoverPresentationController?.sourceView = addButton
        present(plusButtonFloatingPanel, animated: true)
        #endif
    }

    #if !ISEXTENSION
    private func findPreviewViewController() -> PreviewViewController? {
        if let detailsNavigationViewController = splitViewController?.viewController(for: .secondary) as? UINavigationController,
           let previewViewController = detailsNavigationViewController.topViewController as? PreviewViewController {
            return previewViewController
        }
        return nil
    }
    #endif

    func buttonMenuClicked() {
        #if !ISEXTENSION
        let previewViewController = findPreviewViewController()
        previewViewController?.hideFloatingPanel(true)

        let menuViewController = MenuViewController(driveFileManager: driveFileManager, isModallyPresented: true) {
            previewViewController?.hideFloatingPanel(false)
        }

        let menuNavigationController = UINavigationController(rootViewController: menuViewController)
        menuViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .stop,
            primaryAction: UIAction { _ in
                menuNavigationController.dismiss(animated: true)
            }
        )

        menuNavigationController.modalPresentationStyle = .formSheet
        present(menuNavigationController, animated: true)
        #endif
    }
}

enum SidebarDestination {
    case home
    case menu
    case photoList
    case file(FileListViewModel)
}

protocol SidebarViewControllerDelegate: AnyObject {
    func didSelectItem(destination: SidebarDestination)
}
