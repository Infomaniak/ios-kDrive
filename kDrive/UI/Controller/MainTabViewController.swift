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

import FloatingPanel
import InfomaniakBugTracker
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

/// Enum to explicit tab names
public enum MainTabBarIndex: Int {
    case files = 0
    case home = 1
    case gallery = 3
    case profile = 4
}

// class RootViewController: UISplitViewController {
//    @LazyInjectService var router: AppNavigable
//    let driveFileManager: DriveFileManager
//
//    init(driveFileManager: DriveFileManager) {
//        self.driveFileManager = driveFileManager
//        var rootViewControllers = [UIViewController]()
//        rootViewControllers.append(Self.initRootMenuViewController(driveFileManager: driveFileManager))
////        rootViewControllers.append(Self.initHomeViewController(driveFileManager: driveFileManager))
////        rootViewControllers.append(Self.initFakeViewController())
////        rootViewControllers.append(Self.initPhotoListViewController(with: PhotoListViewModel(driveFileManager:
/// driveFileManager)))
////        rootViewControllers.append(Self.initMenuViewController(driveFileManager: driveFileManager))
//        super.init(style: .doubleColumn)
//        preferredDisplayMode = .oneBesideSecondary
//        viewControllers = rootViewControllers
//    }
//
//    @available(*, unavailable)
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    private static func generateProfileTabImages(image: UIImage) -> (UIImage, UIImage) {
//        let iconSize = 28.0
//
//        let selectedImage = image
//            .resize(size: CGSize(width: iconSize + 2, height: iconSize + 2))
//            .maskImageWithRoundedRect(
//                cornerRadius: CGFloat((iconSize + 2) / 2),
//                borderWidth: 2,
//                borderColor: KDriveResourcesAsset.infomaniakColor.color
//            )
//            .withRenderingMode(.alwaysOriginal)
//
//        let image = image
//            .resize(size: CGSize(width: iconSize, height: iconSize))
//            .maskImageWithRoundedRect(cornerRadius: CGFloat(iconSize / 2), borderWidth: 0, borderColor: nil)
//            .withRenderingMode(.alwaysOriginal)
//        return (image, selectedImage)
//    }
//
//    private static func initHomeViewController(driveFileManager: DriveFileManager) -> UIViewController {
//        let homeViewController = HomeViewController(driveFileManager: driveFileManager)
//        let navigationViewController = TitleSizeAdjustingNavigationController(rootViewController: homeViewController)
//        navigationViewController.navigationBar.prefersLargeTitles = true
//        navigationViewController.restorationIdentifier = String(describing: HomeViewController.self)
//        navigationViewController.tabBarItem.accessibilityLabel = KDriveResourcesStrings.Localizable.homeTitle
//        navigationViewController.tabBarItem.image = KDriveResourcesAsset.house.image
//        navigationViewController.tabBarItem.selectedImage = KDriveResourcesAsset.houseFill.image
//        return navigationViewController
//    }
//
//    private static func initRootMenuViewController(driveFileManager: DriveFileManager) -> UIViewController {
//        let homeViewController = SidebarViewController()
//        let navigationViewController = TitleSizeAdjustingNavigationController(rootViewController: homeViewController)
//        navigationViewController.navigationBar.prefersLargeTitles = true
//        navigationViewController.tabBarItem.accessibilityLabel = KDriveResourcesStrings.Localizable.homeTitle
//        navigationViewController.tabBarItem.image = KDriveResourcesAsset.folder.image
//        navigationViewController.tabBarItem.selectedImage = KDriveResourcesAsset.folderFilledTab.image
//        return navigationViewController
//    }
//
//    private static func initMenuViewController(driveFileManager: DriveFileManager) -> UIViewController {
//        let menuViewController = MenuViewController(driveFileManager: driveFileManager)
//        let navigationViewController = TitleSizeAdjustingNavigationController(rootViewController: menuViewController)
//        let (placeholder, placeholderSelected) = generateProfileTabImages(image: KDriveResourcesAsset.placeholderAvatar.image)
//        navigationViewController.restorationIdentifier = String(describing: MenuViewController.self)
//        navigationViewController.tabBarItem.accessibilityLabel = KDriveResourcesStrings.Localizable.menuTitle
//        navigationViewController.tabBarItem.image = placeholder
//        navigationViewController.tabBarItem.selectedImage = placeholderSelected
//        return navigationViewController
//    }
//
//    private static func initFakeViewController() -> UIViewController {
//        let fakeViewController = UIViewController()
//        fakeViewController.tabBarItem.isEnabled = false
//        return fakeViewController
//    }
//
//    private static func initPhotoListViewController(with viewModel: FileListViewModel) -> UIViewController {
//        let photoListViewController = PhotoListViewController(viewModel: viewModel)
//        let navigationViewController = TitleSizeAdjustingNavigationController(rootViewController: photoListViewController)
//        navigationViewController.restorationIdentifier = String(describing: PhotoListViewController.self)
//        navigationViewController.navigationBar.prefersLargeTitles = true
//        navigationViewController.tabBarItem.accessibilityLabel = viewModel.title
//        navigationViewController.tabBarItem.image = KDriveResourcesAsset.mediaInline.image
//        navigationViewController.tabBarItem.selectedImage = KDriveResourcesAsset.mediaBold.image
//        return navigationViewController
//    }
// }

class RootViewController: UISplitViewController, SidebarViewControllerDelegate {
    let sidebarViewController = SidebarViewController()
    let detailViewController = DetailViewController()
    let driveFileManager: DriveFileManager

    init(driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
        super.init(style: .doubleColumn)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        sidebarViewController.delegate = self

        let sidebarNav = UINavigationController(rootViewController: sidebarViewController)
        let detailNav = UINavigationController(rootViewController: detailViewController)

        viewControllers = [sidebarNav, detailNav]
        preferredDisplayMode = .oneBesideSecondary
    }

    // MARK: - SidebarViewControllerDelegate

    func didSelectItem(named folderName: Int) {
        
        let destinationViewModel: FileListViewModel
        switch folderName {
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
            destinationViewModel = MySharesViewModel(driveFileManager: driveFileManager) // à changer
        }

        let destinationViewController = FileListViewController(viewModel: destinationViewModel)

        if let detailNav = viewControllers.last as? UINavigationController {
            detailNav.setViewControllers([destinationViewController], animated: true)
        }
    }

//    func didSelectItem(named: String) {
//        detailViewController.updateDetail(with: named)
//    }
}

class DetailViewController: UIViewController {
    private var label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        label.text = "Select a folder"
        label.textAlignment = .center

        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        // Contraintes pour centrer le texte
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func updateDetail(with item: String) {
        label.text = "You selected: \(item)"
    }
}

class MainTabViewController: UITabBarController, Restorable, PlusButtonObserver {
    /// Tracking the last selection date to detect double tap
    private var lastInteraction: Date?

    /// Time between two tap events that feels alright for a double tap
    private static let doubleTapInterval = TimeInterval(0.350)

    // swiftlint:disable:next weak_delegate
    var photoPickerDelegate = PhotoPickerDelegate()

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var uploadDataSource: UploadServiceDataSourceable
    @LazyInjectService var fileImportHelper: FileImportHelper
    @LazyInjectService var router: AppNavigable

    let driveFileManager: DriveFileManager

    lazy var legacyTabBarActive: Bool = {
        if #available(iOS 18.0, *),
           UIDevice.current.userInterfaceIdiom == .pad {
            self.isTabBarHidden = true
            return true
        }
        return false
    }()

    var tabBarHeightConstraint: NSLayoutConstraint?

    lazy var legacyTabBar = MainTabBar()

    init(driveFileManager: DriveFileManager, selectedIndex: Int? = nil) {
        self.driveFileManager = driveFileManager
        var rootViewControllers = [UIViewController]()
        rootViewControllers.append(Self.initHomeViewController(driveFileManager: driveFileManager))
        rootViewControllers.append(Self.initRootMenuViewController(driveFileManager: driveFileManager))
        rootViewControllers.append(Self.initFakeViewController())
        rootViewControllers.append(Self.initPhotoListViewController(with: PhotoListViewModel(driveFileManager: driveFileManager)))
        rootViewControllers.append(Self.initMenuViewController(driveFileManager: driveFileManager))
        super.init(nibName: nil, bundle: nil)
        viewControllers = rootViewControllers

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

        restorationIdentifier = defaultRestorationIdentifier

        setValue(MainTabBar(frame: tabBar.frame), forKey: "tabBar")

        delegate = self
        tabBar.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        (tabBar as? MainTabBar)?.tabDelegate = self
        photoPickerDelegate.viewController = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidTakeScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        willLayoutLegacyTabBarIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        didLayoutLegacyTabBarIfNeeded()

        if view.safeAreaInsets.bottom == 0 {
            let newFrame = CGRect(
                origin: CGPoint(x: 0, y: view.frame.size.height - tabBar.frame.height - 16),
                size: tabBar.frame.size
            )
            tabBar.frame = newFrame
        }
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
        let homeViewController = RootMenuViewController(driveFileManager: driveFileManager, selectMode: false)
        let navigationViewController = TitleSizeAdjustingNavigationController(rootViewController: homeViewController)
        navigationViewController.navigationBar.prefersLargeTitles = true
        navigationViewController.tabBarItem.accessibilityLabel = KDriveResourcesStrings.Localizable.homeTitle
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
        let photoListViewController = PhotoListViewController(viewModel: viewModel)
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

    func updateTabBarProfilePicture() {
        accountManager.currentAccount?.user?.getAvatar { [weak self] image in
            guard let self,
                  let menuViewController = viewControllers?
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
            .topViewController as? FileListViewController,
            filesViewController.viewModel.currentDirectory.id >= DriveFileManager.constants.rootID {
            return (filesViewController.driveFileManager, filesViewController.viewModel.currentDirectory)
        } else {
            let file = driveFileManager.getCachedMyFilesRoot()
            return (driveFileManager, file)
        }
    }

    func updateCenterButton() {
        let (_, currentDirectory) = getCurrentDirectory()
        guard let currentDirectory else {
            (tabBar as? MainTabBar)?.centerButton?.isEnabled = false
            return
        }
        let canCreateFile = currentDirectory.isRoot || currentDirectory.capabilities.canCreateFile
        (tabBar as? MainTabBar)?.centerButton?.isEnabled = canCreateFile
    }

    @objc private func userDidTakeScreenshot() {
        if (accountManager.currentAccount?.user.isStaff) == true {
            present(BugTrackerViewController(), animated: true)
        }
    }
}

// - MARK: MainTabBarDelegate
extension MainTabViewController: MainTabBarDelegate {
    func plusButtonPressed() {
        let (currentDriveFileManager, currentDirectory) = getCurrentDirectory()
        guard let currentDirectory else { return }

        let floatingPanelViewController = AdaptiveDriveFloatingPanelController()
        let fromFileList = (selectedViewController as? UINavigationController)?.topViewController is FileListViewController
        let plusButtonFloatingPanel = PlusButtonFloatingPanelViewController(
            driveFileManager: currentDriveFileManager,
            folder: currentDirectory,
            presentedAboveFileList: fromFileList
        )
        floatingPanelViewController.isRemovalInteractionEnabled = true
        floatingPanelViewController.delegate = plusButtonFloatingPanel

        floatingPanelViewController.set(contentViewController: plusButtonFloatingPanel)
        floatingPanelViewController.trackAndObserve(scrollView: plusButtonFloatingPanel.tableView)
        present(floatingPanelViewController, animated: true)
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

        matomo.track(eventWithCategory: .account, name: "switchDoubleTap")
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
    @MainActor func didUpdateCurrentAccountInformations(_ currentAccount: Account) {
        updateTabBarProfilePicture()
        for viewController in viewControllers ?? [] where viewController.isViewLoaded {
            ((viewController as? UINavigationController)?.viewControllers.first as? UpdateAccountDelegate)?
                .didUpdateCurrentAccountInformations(currentAccount)
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension MainTabViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let documentPicker = controller as? DriveImportDocumentPickerViewController {
            for url in urls {
                let targetURL = fileImportHelper.generateImportURL(for: url.uti)

                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }

                    try FileManager.default.moveItem(at: url, to: targetURL)
                    let newFile = UploadFile(
                        parentDirectoryId: documentPicker.importDriveDirectory.id,
                        userId: accountManager.currentUserId,
                        driveId: documentPicker.importDriveDirectory.driveId,
                        url: targetURL,
                        name: url.lastPathComponent
                    )

                    uploadDataSource.saveToRealm(newFile,
                                                 itemIdentifier: nil,
                                                 addToQueue: true)
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
                }
            }
        }
    }
}
