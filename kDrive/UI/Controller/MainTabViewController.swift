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

import InfomaniakBugTracker
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakCoreSwiftUI
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

/// Enum to explicit tab names
public enum MainTabBarIndex {
    case home
    case files
    case gallery
    case profile

    public var rawValue: Int {
        switch self {
        case .home:
            return 0
        case .files:
            return 1
        case .gallery:
            if #available(iOS 26.0, *) {
                return 2
            } else {
                return 3
            }
        case .profile:
            if #available(iOS 26.0, *) {
                return 3
            } else {
                return 4
            }
        }
    }
}

class RootSplitViewController: UISplitViewController, SidebarViewControllerDelegate, UISplitViewControllerDelegate {
    let driveFileManager: DriveFileManager
    private weak var expandedNavigationController: UINavigationController?
    private var compactFilesRoot: UIViewController?
    var lastSelectedDestination: SidebarDestination? {
        didSet {
            let destination = lastSelectedDestination

            let sidebarNavigationController = viewController(for: .primary) as? UINavigationController
            let sidebarViewController = sidebarNavigationController?.viewControllers.first as? SidebarViewController

            sidebarViewController?.lastSelectedDestination = destination
        }
    }

    init(driveFileManager: DriveFileManager, selectedIndex: Int? = nil, lastSelectedDestination: SidebarDestination? = nil) {
        self.driveFileManager = driveFileManager
        self.lastSelectedDestination = lastSelectedDestination
        super.init(style: .doubleColumn)

        let sidebarViewController = SidebarViewController(
            driveFileManager: driveFileManager,
            selectMode: false,
            isCompactView: false,
            lastSelectedDestination: lastSelectedDestination
        )
        let detailViewController = HomeViewController(driveFileManager: driveFileManager)

        sidebarViewController.delegate = self

        let sidebarNav = UINavigationController(rootViewController: sidebarViewController)
        let detailNav = UINavigationController(rootViewController: detailViewController)

        viewControllers = [sidebarNav, detailNav]
        setViewController(
            MainTabViewController(driveFileManager: driveFileManager, selectedIndex: selectedIndex),
            for: .compact
        )
        preferredDisplayMode = .oneBesideSecondary
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLayoutTraits(from windowTraits: UITraitCollection) {
        if #available(iOS 17.0, *) {
            // A large iPhone in landscape still has only enough height for the phone UI.
            // Remove the override when space returns so UIKit can expand the same container.
            if windowTraits.userInterfaceIdiom == .phone && windowTraits.iskDriveCompactSize {
                traitOverrides.horizontalSizeClass = .compact
            } else {
                traitOverrides.remove(UITraitHorizontalSizeClass.self)
            }
        }
    }

    func splitViewController(_ svc: UISplitViewController,
                             topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column)
        -> UISplitViewController.Column {
        switchToCompactRestoration()
        return .compact
    }

    func splitViewController(_ svc: UISplitViewController,
                             displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode)
        -> UISplitViewController.DisplayMode {
        switchToRegularRestoration()
        return .oneBesideSecondary
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !isCollapsed {
            switchToRegularRestoration()
        }
    }

    private func switchToRegularRestoration() {
        guard expandedNavigationController == nil,
              let detailNavigationController = viewController(for: .secondary) as? UINavigationController,
              let mainTabViewController = viewController(for: .compact) as? MainTabViewController,
              let selectedNavigationController = mainTabViewController.selectedViewController as? UINavigationController else {
            return
        }

        // Move the existing stack, preserving previews, scroll positions and in-progress edits.
        // Detach it first: a view controller cannot belong to two navigation controllers.
        expandedNavigationController = selectedNavigationController
        var stack = selectedNavigationController.viewControllers
        // The wide layout already has a sidebar; keep the compact location picker for the return trip.
        if stack.count > 1, stack.first is SidebarViewController {
            compactFilesRoot = stack.removeFirst()
        }
        detailNavigationController.navigationBar.prefersLargeTitles = selectedNavigationController.navigationBar
            .prefersLargeTitles
        detailNavigationController.setNavigationBarHidden(selectedNavigationController.isNavigationBarHidden, animated: false)
        selectedNavigationController.setViewControllers([UIViewController()], animated: false)
        detailNavigationController.setViewControllers(stack, animated: false)
    }

    private func switchToCompactRestoration() {
        guard let detailNavigationController = viewController(for: .secondary) as? UINavigationController,
              let expandedNavigationController else {
            return
        }

        var stack = detailNavigationController.viewControllers
        if let compactFilesRoot {
            stack.insert(compactFilesRoot, at: 0)
        }
        expandedNavigationController.setNavigationBarHidden(detailNavigationController.isNavigationBarHidden, animated: false)
        detailNavigationController.setViewControllers([UIViewController()], animated: false)
        expandedNavigationController.setViewControllers(stack, animated: false)
        self.expandedNavigationController = nil
        compactFilesRoot = nil
    }

    // MARK: - SidebarViewControllerDelegate

    func didSelectItem(destination: SidebarDestination) {
        guard let mainTabBarViewController = viewController(for: .compact) as? MainTabViewController else { return }
        let wasExpanded = expandedNavigationController != nil || !isCollapsed
        switchToCompactRestoration()

        switch destination {
        case .home:
            mainTabBarViewController.selectedIndex = MainTabBarIndex.home.rawValue
        case .photoList:
            mainTabBarViewController.selectedIndex = MainTabBarIndex.gallery.rawValue
        case .menu:
            mainTabBarViewController.selectedIndex = MainTabBarIndex.profile.rawValue
        case .file(let fileListViewModel):
            mainTabBarViewController.selectedIndex = MainTabBarIndex.files.rawValue
            if let filesNav = mainTabBarViewController
                .viewControllers?[safe: mainTabBarViewController.selectedIndex] as? UINavigationController {
                let compactViewController = FileListViewController(viewModel: fileListViewModel)
                filesNav.popToRootViewController(animated: false)
                filesNav.pushViewController(compactViewController, animated: false)
            }
        }
        lastSelectedDestination = destination
        UserDefaults.shared.lastSelectedTab = mainTabBarViewController.selectedIndex
        if wasExpanded {
            switchToRegularRestoration()
        }
    }
}

extension RootSplitViewController: UpdateAccountDelegate {
    func didUpdateCurrentUserProfile(_ currentUser: UserProfile) {
        (viewController(for: .compact) as? MainTabViewController)?.didUpdateCurrentUserProfile(currentUser)
        for column in [UISplitViewController.Column.primary, .secondary] {
            let navigationController = viewController(for: column) as? UINavigationController
            (navigationController?.viewControllers.first as? UpdateAccountDelegate)?.didUpdateCurrentUserProfile(currentUser)
        }
    }
}

class MainTabViewController: UITabBarController, Restorable, PlusButtonObserver {
    /// Tracking the last selection date to detect double tap
    private var lastInteraction: Date?

    /// Time between two tap events that feels alright for a double tap
    private static let doubleTapInterval = TimeInterval(0.350)

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var uploadDataSource: UploadServiceDataSourceable
    @LazyInjectService var fileImportHelper: FileImportHelper
    @LazyInjectService var router: AppNavigable

    let driveFileManager: DriveFileManager
    let photoPickerDelegate = PhotoPickerDelegate()

    private var buttonAdd: UIButton?
    private var mediaHelper: OpenMediaHelper?

    lazy var legacyTabBarActive: Bool = {
        if #available(iOS 26.0, *),
           UIDevice.current.userInterfaceIdiom == .pad {
            self.isTabBarHidden = false
            return false
        }
        if #available(iOS 18.0, *),
           UIDevice.current.userInterfaceIdiom == .pad {
            self.isTabBarHidden = true
            return true
        }
        return false
    }()

    var tabBarHeightConstraint: NSLayoutConstraint?
    var buttonAddBottomConstraint: NSLayoutConstraint?

    lazy var legacyTabBar = MainTabBar()

    init(driveFileManager: DriveFileManager, selectedIndex: Int? = nil) {
        self.driveFileManager = driveFileManager
        var rootViewControllers = [UIViewController]()
        rootViewControllers.append(Self.initHomeViewController(driveFileManager: driveFileManager))
        rootViewControllers.append(Self.initRootMenuViewController(driveFileManager: driveFileManager))
        if #unavailable(iOS 26.0) {
            rootViewControllers.append(Self.initFakeViewController())
        }
        rootViewControllers.append(Self.initPhotoListViewController(with: PhotoListViewModel(driveFileManager: driveFileManager)))
        rootViewControllers.append(Self.initMenuViewController(driveFileManager: driveFileManager))
        super.init(nibName: nil, bundle: nil)
        viewControllers = rootViewControllers

        if let filesNav = viewControllers?[safe: MainTabBarIndex.files.rawValue] as? UINavigationController,
           let sideBarVC = filesNav.viewControllers.first as? SidebarViewController {
            sideBarVC.mainTabViewControllerDelegate = self
        }

        if let selectedIndex {
            self.selectedIndex = selectedIndex
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addLegacyTabBarIfNeeded()
        setupTabBar()
        updateCenterButton()

        restorationIdentifier = defaultRestorationIdentifier

        delegate = self
        photoPickerDelegate.viewController = self
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        willLayoutLegacyTabBarIfNeeded()

        if #available(iOS 26.0, *) {
            willLayoutButtonAddIfNeeded()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        didLayoutLegacyTabBarIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureTabBar()
        updateTabBarProfilePicture()
    }

    private static func initHomeViewController(driveFileManager: DriveFileManager) -> UIViewController {
        let homeViewController = HomeViewController(driveFileManager: driveFileManager)
        let navigationViewController = TitleSizeAdjustingNavigationController(rootViewController: homeViewController)
        navigationViewController.navigationBar.prefersLargeTitles = true
        navigationViewController.restorationIdentifier = String(describing: HomeViewController.self)
        navigationViewController.tabBarItem.accessibilityLabel = KDriveResourcesStrings.Localizable.homeTitle
        navigationViewController.tabBarItem.image = KDriveResourcesAsset.house.image
        navigationViewController.tabBarItem.selectedImage = KDriveResourcesAsset.houseFill.image
        return navigationViewController
    }

    private static func initRootMenuViewController(driveFileManager: DriveFileManager) -> UIViewController {
        let homeViewController = SidebarViewController(
            driveFileManager: driveFileManager,
            selectMode: false,
            isCompactView: true
        )
        let navigationViewController = TitleSizeAdjustingNavigationController(rootViewController: homeViewController)
        navigationViewController.navigationBar.prefersLargeTitles = true
        navigationViewController.tabBarItem.accessibilityLabel = KDriveResourcesStrings.Localizable.fileListTitle
        navigationViewController.tabBarItem.image = KDriveResourcesAsset.folder.image
        navigationViewController.tabBarItem.selectedImage = KDriveResourcesAsset.folderFilledTab.image
        return navigationViewController
    }

    private static func initMenuViewController(driveFileManager: DriveFileManager) -> UIViewController {
        let menuViewController = MenuViewController(driveFileManager: driveFileManager)
        let navigationViewController = TitleSizeAdjustingNavigationController(rootViewController: menuViewController)
        let (placeholder, placeholderSelected) = generateProfileTabImages(image: KDriveResourcesAsset.placeholderAvatar.image)
        navigationViewController.restorationIdentifier = String(describing: MenuViewController.self)
        navigationViewController.tabBarItem.accessibilityLabel = KDriveResourcesStrings.Localizable.menuTitle
        navigationViewController.tabBarItem.image = placeholder
        navigationViewController.tabBarItem.selectedImage = placeholderSelected
        return navigationViewController
    }

    private static func initFakeViewController() -> UIViewController {
        let fakeViewController = UIViewController()
        fakeViewController.tabBarItem.isEnabled = false
        return fakeViewController
    }

    private static func initPhotoListViewController(with viewModel: FileListViewModel) -> UIViewController {
        let photoListViewController = PhotoListViewController(viewModel: viewModel, listLayout: PhotoListLayout())
        let navigationViewController = TitleSizeAdjustingNavigationController(rootViewController: photoListViewController)
        navigationViewController.restorationIdentifier = String(describing: PhotoListViewController.self)
        navigationViewController.navigationBar.prefersLargeTitles = true
        navigationViewController.tabBarItem.accessibilityLabel = viewModel.title
        navigationViewController.tabBarItem.image = KDriveResourcesAsset.mediaInline.image
        navigationViewController.tabBarItem.selectedImage = KDriveResourcesAsset.mediaBold.image
        return navigationViewController
    }

    private func configureTabBar() {
        var spacing: CGFloat
        var itemWidth: CGFloat
        var inset: UIEdgeInsets

        if view.frame.width < 375 {
            spacing = 0
            itemWidth = 28
            inset = .zero
        } else {
            spacing = 35
            itemWidth = 35
            inset = UIEdgeInsets(top: -2, left: -2, bottom: -2, right: -2)
        }

        tabBar.itemSpacing = spacing
        tabBar.itemWidth = itemWidth
        tabBar.itemPositioning = .centered
        for item in tabBar.items ?? [] {
            item.title = ""
            item.imageInsets = inset
        }
    }

    private func setupTabBar() {
        if #available(iOS 26.0, *) {
            setupButtonAdd()
        } else {
            setValue(MainTabBar(frame: tabBar.frame), forKey: "tabBar")
            tabBar.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
            (tabBar as? MainTabBar)?.tabDelegate = self
        }
    }

    @objc func centerButtonAction(sender _: UIButton) {
        plusButtonPressed()
    }

    @available(iOS 26.0, *)
    private func setupButtonAdd() {
        guard buttonAdd == nil else { return }

        var config = UIButton.Configuration.prominentGlass()
        config.image = KDriveAsset.plus.image

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonAdd

        button.addTarget(
            self,
            action: #selector(centerButtonAction),
            for: .touchUpInside
        )

        view.addSubview(button)

        buttonAddBottomConstraint = button.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor
        )

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -UIConstants.Padding.standard
            ),
            buttonAddBottomConstraint!,
            button.widthAnchor.constraint(equalToConstant: IKButtonHeight.large),
            button.heightAnchor.constraint(equalToConstant: IKButtonHeight.large)
        ])

        buttonAdd = button
    }

    @available(iOS 26.0, *)
    private func willLayoutButtonAddIfNeeded() {
        guard let buttonAdd else { return }

        if traitCollection.horizontalSizeClass == .compact {
            buttonAddBottomConstraint?.isActive = false

            let newConstraint = buttonAdd.bottomAnchor.constraint(
                equalTo: tabBar.topAnchor,
                constant: -UIConstants.Padding.medium
            )
            newConstraint.isActive = true
            buttonAddBottomConstraint = newConstraint
        }
    }

    func hideButtonAdd(_ hide: Bool) {
        guard let buttonAdd else { return }
        buttonAdd.alpha = hide ? 0 : 1
    }

    func updateTabBarProfilePicture() {
        Task {
            guard let image = await accountManager.getCurrentUser()?.getAvatar() else { return }

            guard let menuViewController = viewControllers?
                .compactMap({
                    ($0 as? TitleSizeAdjustingNavigationController)?.viewControllers.first as? MenuViewController
                }),
                let menuNavigationViewController = menuViewController.first?.navigationController else { return }

            let (placeholder, placeholderSelected) = Self.generateProfileTabImages(image: image)
            menuNavigationViewController.tabBarItem.image = placeholder
            menuNavigationViewController.tabBarItem.selectedImage = placeholderSelected
        }
    }

    private static func generateProfileTabImages(image: UIImage) -> (UIImage, UIImage) {
        let iconSize = 28.0

        let selectedImage = image
            .resize(size: CGSize(width: iconSize + 2, height: iconSize + 2))
            .maskImageWithRoundedRect(
                cornerRadius: CGFloat((iconSize + 2) / 2),
                borderWidth: 2,
                borderColor: KDriveResourcesAsset.infomaniakColor.color
            )
            .withRenderingMode(.alwaysOriginal)

        let image = image
            .resize(size: CGSize(width: iconSize, height: iconSize))
            .maskImageWithRoundedRect(cornerRadius: CGFloat(iconSize / 2), borderWidth: 0, borderColor: nil)
            .withRenderingMode(.alwaysOriginal)
        return (image, selectedImage)
    }

    func getCurrentDirectory() -> (DriveFileManager, File?) {
        if let filesViewController = (selectedViewController as? UINavigationController)?
            .topViewController as? FileListViewController {
            return (filesViewController.driveFileManager, filesViewController.viewModel.currentDirectory)
        } else {
            let file = driveFileManager.getCachedMyFilesRoot()
            return (driveFileManager, file)
        }
    }

    func updateCenterButton() {
        let (_, currentDirectory) = getCurrentDirectory()
        guard let currentDirectory,
              currentDirectory.id >= DriveFileManager.constants.rootID,
              !currentDirectory.isTrashed else {
            (tabBar as? MainTabBar)?.centerButton?.isEnabled = false
            hideButtonAdd(true)
            return
        }
        if #available(iOS 26.0, *),
           selectedIndex == MainTabBarIndex.profile.rawValue {
            hideButtonAdd(true)
            return
        }
        let canCreateFile = currentDirectory.isRoot || currentDirectory.capabilities.canCreateFile
        (tabBar as? MainTabBar)?.centerButton?.isEnabled = canCreateFile
        hideButtonAdd(!canCreateFile)
    }
}

// - MARK: MainTabBarDelegate
extension MainTabViewController: MainTabBarDelegate {
    func plusButtonPressed() {
        let (currentDriveFileManager, currentDirectory) = getCurrentDirectory()
        guard let currentDirectory else { return }

        let fromFileList = (selectedViewController as? UINavigationController)?.topViewController is FileListViewController
        let plusButtonFloatingPanel = PlusButtonFloatingPanelViewController(
            driveFileManager: currentDriveFileManager,
            folder: currentDirectory,
            presentedAboveFileList: fromFileList
        )

        mediaHelper = plusButtonFloatingPanel.mediaHelper

        present(plusButtonFloatingPanel, animated: true)
    }

    func avatarLongTouch() {
        guard let rootNavigationController = viewControllers?[safe: MainTabBarIndex.profile.rawValue] as? UINavigationController
        else {
            return
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        selectedIndex = MainTabBarIndex.profile.rawValue

        router.presentAccountViewController(navigationController: rootNavigationController, animated: true)

        matomo.track(eventWithCategory: .account, name: "longPressDirectAccess")
    }

    func avatarDoubleTap() {
        accountManager.switchToNextAvailableAccount()
        guard let accountManager = accountManager.currentDriveFileManager else {
            return
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        _ = router.showMainViewController(driveFileManager: accountManager,
                                          selectedIndex: MainTabBarIndex.profile.rawValue)
        Task {
            await router.refreshCacheScanLibraryAndUpload(preload: false, isSwitching: true)
        }

        matomo.track(eventWithCategory: .account, name: "switchDoubleTap")
    }

    // MARK: - State restoration

    var currentSceneMetadata: [AnyHashable: Any] {
        [:]
    }
}

// MARK: - Tab bar controller delegate

extension MainTabViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let navigationController = viewController as? UINavigationController else {
            return false
        }

        defer {
            lastInteraction = Date()
        }

        let topViewController = navigationController.topViewController
        if let homeViewController = topViewController as? HomeViewController {
            homeViewController.presentedFromTabBar()
        }

        if tabBarController.selectedViewController == viewController {
            // Detect double tap on menu
            if topViewController is MenuViewController,
               let lastDate = lastInteraction,
               Date().timeIntervalSince(lastDate) <= Self.doubleTapInterval {
                avatarDoubleTap()
                return true
            }

            if let viewController = topViewController as? TopScrollable {
                viewController.scrollToTop()
            }
        }

        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let selectedIndex = tabBarController.selectedIndex

        UserDefaults.shared.lastSelectedTab = selectedIndex
        saveSelectedTabUserActivity(selectedIndex)
        updateCenterButton()

        guard let rootViewController = tabBarController.splitViewController as? RootSplitViewController else { return }
        switch selectedIndex {
        case MainTabBarIndex.gallery.rawValue:
            rootViewController.lastSelectedDestination = .photoList
        case MainTabBarIndex.profile.rawValue:
            rootViewController.lastSelectedDestination = .menu
        case MainTabBarIndex.files.rawValue:
            if let fileList = (viewController as? UINavigationController)?.topViewController as? FileListViewController {
                rootViewController.lastSelectedDestination = .file(fileList.viewModel)
            } else {
                rootViewController.lastSelectedDestination = nil
            }
        default:
            rootViewController.lastSelectedDestination = .home
        }
    }

    // MARK: - State restoration

    private func saveSelectedTabUserActivity(_ index: Int) {
        let metadata = [SceneRestorationKeys.selectedIndex.rawValue: index]
        let userActivity = currentUserActivity
        userActivity.userInfo = metadata

        view.window?.windowScene?.userActivity = userActivity
    }
}

// MARK: - SwitchAccountDelegate, SwitchDriveDelegate

extension MainTabViewController: UpdateAccountDelegate {
    @MainActor func didUpdateCurrentUserProfile(_ currentUser: UserProfile) {
        updateTabBarProfilePicture()
        for viewController in viewControllers ?? [] where viewController.isViewLoaded {
            ((viewController as? UINavigationController)?.viewControllers.first as? UpdateAccountDelegate)?
                .didUpdateCurrentUserProfile(currentUser)
        }
    }
}

// MARK: - MainTabViewControllerDelegate

extension MainTabViewController: MainTabViewControllerDelegate {
    func setLastSelectedDestination(_ destination: SidebarDestination?) {
        guard let rootSplitViewController = splitViewController as? RootSplitViewController else { return }
        rootSplitViewController.lastSelectedDestination = destination
    }
}
