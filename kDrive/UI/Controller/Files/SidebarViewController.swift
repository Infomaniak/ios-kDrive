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
    typealias MenuDataSource = UICollectionViewDiffableDataSource<RootMenuSection, RootMenuItem>
    typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<RootMenuSection, RootMenuItem>
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

    enum RootMenuSection {
        case main
        case recent
        case first
        case second
        case third

        var title: String {
            switch self {
            case .main: return KDriveResourcesStrings.Localizable.allFilesTitle
            case .recent: return KDriveResourcesStrings.Localizable.recentTitle
            default: return ""
            }
        }
    }

    struct RootMenuItem: Equatable, Hashable {
        var id: Int {
            return destination.hashValue
        }

        let name: String
        var image: UIImage?
        let destination: RootMenuDestination?
        var isFirst = false
        var isLast = false
        var priority = 0
        var isHeader = false

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
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.trashTitle,
                                                                 image: KDriveResourcesAsset
                                                                     .delete.image,
                                                                 destination: .file(DriveFileManager
                                                                     .trashRootFile))]

    private static var expandableItems: [RootMenuItem] = [
        RootMenuItem(name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
                     image: KDriveResourcesAsset.folderSelect2.image,
                     destination: .file(DriveFileManager.sharedWithMeRootFile)),
        RootMenuItem(name: KDriveResourcesStrings.Localizable.mySharesTitle,
                     image: KDriveResourcesAsset.folderSelect.image,
                     destination: .file(DriveFileManager.mySharedRootFile)),
        RootMenuItem(
            name: KDriveResourcesStrings.Localizable.offlineFileTitle,
            image: KDriveResourcesAsset.availableOffline.image,
            destination: .file(DriveFileManager.offlineRoot)
        )
    ]

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

    var sections: [RootMenuSection] {
        [RootMenuSection.first, RootMenuSection.second, RootMenuSection.third]
    }

    weak var delegate: SidebarViewControllerDelegate?

    let driveFileManager: DriveFileManager
    private var rootChildrenObservationToken: NotificationToken?
    var rootViewChildren: [File]?
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
            return snapshotForCompactView()
        } else {
            return snapshotForLargeView(userRootFolders: userRootFolders)
        }
    }

    private func applySectionSnapshots() {
        let userRootFolders = rootViewChildren?.compactMap {
            RootMenuItem(
                name: $0.formattedLocalizedName,
                image: $0.icon,
                destination: .file($0),
                priority: 1
            )
        } ?? []
        let header2 = RootMenuItem(
            name: "Mes fichiers",
            image: nil,
            destination: nil,
            isHeader: true
        )
        let firstSectionItems = SidebarViewController.baseItems
        let secondSectionItems = [header2] + userRootFolders + SidebarViewController.expandableItems
        let sectionsItems = [firstSectionItems, secondSectionItems]

        var firstSS = NSDiffableDataSourceSectionSnapshot<RootMenuItem>()
        firstSS.append(firstSectionItems)
        dataSource.apply(firstSS, to: .first, animatingDifferences: true)

        for (section, items) in zip(sections, sectionsItems) {
            guard let header = items.first, section != .first else { continue }
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<RootMenuItem>()
            sectionSnapshot.append([header])
            let children = Array(items.dropFirst())
            if !children.isEmpty {
                sectionSnapshot.append(children, to: header)
                if UserDefaults.shared.isFilesSectionExtended {
                    sectionSnapshot.expand([header])
                }
            }
            dataSource.apply(sectionSnapshot, to: section, animatingDifferences: true)
        }
    }

    private func snapshotForCompactView() -> DataSourceSnapshot {
        var snapshot = DataSourceSnapshot()
        snapshot.appendSections(sections)
        dataSource.apply(snapshot, animatingDifferences: false)

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

        collectionView.register(cellView: FileCollectionViewCell.self)
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

        dataSource.sectionSnapshotHandlers.willExpandItem = { _ in
            UserDefaults.shared.isFilesSectionExtended = true
        }

        dataSource.sectionSnapshotHandlers.willCollapseItem = { _ in
            UserDefaults.shared.isFilesSectionExtended = false
        }

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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard let previousTraitCollection else { return }
        guard traitCollection.horizontalSizeClass != previousTraitCollection.horizontalSizeClass
            || traitCollection.verticalSizeClass != previousTraitCollection.verticalSizeClass else { return }
        forceRefresh()
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
                if !(isCompactView || selectMode) {
                    applySectionSnapshots()
                }

            case .update(let children, _, _, _):
                rootViewChildren = Array(AnyRealmCollection(children).filesSorted(by: .nameAZ))
                dataSource.apply(itemsSnapshot, animatingDifferences: true)
                if !(isCompactView || selectMode) {
                    applySectionSnapshots()
                }

            case .error:
                break
            }
        }
    }

    func configureDataSource(for collectionView: UICollectionView)
        -> UICollectionViewDiffableDataSource<RootMenuSection, RootMenuItem> {
        if !(isCompactView || selectMode) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
            navigationItem.scrollEdgeAppearance = appearance

            let cellRegistration = UICollectionView
                .CellRegistration<UICollectionViewListCell, RootMenuItem> { cell, _, item in
                    var content = item.isHeader ? UIListContentConfiguration.sidebarHeader() : UIListContentConfiguration
                        .sidebarCell()
                    content.text = item.name
                    content.image = item.image
                    cell.contentConfiguration = content
                    cell.accessories = item.isHeader ? [
                        .outlineDisclosure(
                            options: .init(style: .header),
                        )
                    ] : []
                    cell.indentationLevel = 0
                }

            dataSource = UICollectionViewDiffableDataSource<RootMenuSection, RootMenuItem>(collectionView: collectionView) {
                collectionView, indexPath, menuItem in
                collectionView.dequeueConfiguredReusableCell(
                    using: cellRegistration,
                    for: indexPath,
                    item: menuItem
                )
            }

        } else {
            dataSource = UICollectionViewDiffableDataSource<RootMenuSection, RootMenuItem>(collectionView: collectionView) {
                collectionView, indexPath, menuItem -> UICollectionViewCell? in
                guard let menuSection = self.getSection(for: indexPath.section) else {
                    fatalError("Unknown section")
                }

                switch menuSection {
                case .recent:
                    guard let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: FileCollectionViewCell.identifier,
                        for: indexPath
                    ) as? FileCollectionViewCell else {
                        fatalError("Failed to dequeue cell")
                    }

                    guard case .file(let destinationFile) = menuItem.destination else {
                        fatalError("Unable to find a matching file")
                    }

                    let viewModel = FileViewModel(
                        driveFileManager: self.driveFileManager,
                        file: destinationFile,
                        selectionMode: false
                    )
                    cell.configure(with: viewModel)
                    cell.initStyle(isFirst: menuItem.isFirst, isLast: menuItem.isLast, inFolderSelectMode: true)
                    cell.setEnabled(true)
                    cell.moreButton.isHidden = true

                    return cell
                case .main, .first, .second, .third:
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
            }
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
            if selectMode {
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: -UIConstants.Padding.small,
                    leading: UIConstants.Padding.mediumSmall,
                    bottom: UIConstants.Padding.standard,
                    trailing: UIConstants.Padding.mediumSmall
                )
            } else {
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: -UIConstants.Padding.small,
                    leading: UIConstants.Padding.none,
                    bottom: UIConstants.Padding.standard,
                    trailing: UIConstants.Padding.none
                )
            }

            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                    heightDimension: .estimated(8))

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

        if !(isCompactView || selectMode) {
            let layout = UICollectionViewCompositionalLayout(sectionProvider: { _, layoutEnvironment in
                let listConfig = UICollectionLayoutListConfiguration(appearance: .sidebar)
                return NSCollectionLayoutSection.list(using: listConfig, layoutEnvironment: layoutEnvironment)
            }, configuration: configuration)
            return layout
        } else {
            let layout = UICollectionViewCompositionalLayout(sectionProvider: sectionProvider, configuration: configuration)
            return layout
        }
    }

    @objc func presentSearch() {
        let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager)
        let searchViewController = SearchViewController.instantiateInNavigationController(viewModel: viewModel)
        present(searchViewController, animated: true)
    }

    @objc func forceRefresh() {
        Task { @MainActor in
            setItemsSnapshot(for: collectionView)
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
        } else {
            guard let detailNavigationController = splitViewController?.viewControllers.last as? UINavigationController
            else { return }
            let isDetailAtRoot = detailNavigationController.viewControllers.count == 1

            if selectedIndexPath != indexPath || !isDetailAtRoot {
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

    func getSection(for index: Int) -> RootMenuSection? {
        return sections[safe: index]
    }

    func getIndexOfSection(for menuSection: RootMenuSection) -> Int? {
        return sections.firstIndex(of: menuSection)
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
