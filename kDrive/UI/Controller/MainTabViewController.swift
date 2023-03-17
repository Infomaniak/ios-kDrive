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

import FloatingPanel
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class MainTabViewController: UITabBarController, MainTabBarDelegate {
    // swiftlint:disable weak_delegate
    var photoPickerDelegate = PhotoPickerDelegate()

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var uploadQueue: UploadQueue
    @LazyInjectService var fileImportHelper: FileImportHelper

    override var tabBar: MainTabBar {
        return super.tabBar as! MainTabBar
    }

    var driveFileManager: DriveFileManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        setDriveFileManager(accountManager.currentDriveFileManager) { currentDriveFileManager in
            self.driveFileManager = currentDriveFileManager
        }

        if let driveFileManager = driveFileManager {
            configureRootViewController(at: 1, with: ConcreteFileListViewModel(driveFileManager: driveFileManager, currentDirectory: nil))
            configureRootViewController(at: 3, with: FavoritesViewModel(driveFileManager: driveFileManager, currentDirectory: nil))

            for viewController in viewControllers ?? [] {
                ((viewController as? UINavigationController)?.viewControllers.first as? SwitchDriveDelegate)?.driveFileManager = driveFileManager
            }
        } else {
            viewControllers?.removeAll()
        }

        tabBar.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        delegate = self

        photoPickerDelegate.viewController = self
    }

    private func configureRootViewController(at index: Int, with viewModel: FileListViewModel) {
        let rootNavigationViewController = (viewControllers?[index] as? UINavigationController)
        (rootNavigationViewController?.viewControllers.first as? FileListViewController)?.viewModel = viewModel
        rootNavigationViewController?.tabBarItem.image = viewModel.configuration.tabBarIcon.image
        rootNavigationViewController?.tabBarItem.selectedImage = viewModel.configuration.selectedTabBarIcon.image
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if view.safeAreaInsets.bottom == 0 {
            let newFrame = CGRect(origin: CGPoint(x: 0, y: view.frame.size.height - tabBar.frame.height - 16), size: tabBar.frame.size)
            tabBar.frame = newFrame
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setAccessibilityLabels()
        configureTabBar()
        updateTabBarProfilePicture()
    }

    private func setAccessibilityLabels() {
        tabBar.items?[0].accessibilityLabel = KDriveResourcesStrings.Localizable.homeTitle
        tabBar.items?[1].accessibilityLabel = KDriveResourcesStrings.Localizable.fileListTitle
        tabBar.items?[3].accessibilityLabel = KDriveResourcesStrings.Localizable.favoritesTitle
        tabBar.items?[4].accessibilityLabel = KDriveResourcesStrings.Localizable.menuTitle
    }

    private func configureTabBar() {
        var spacing: CGFloat
        var itemWidth: CGFloat
        var inset: UIEdgeInsets

        if view.frame.width < 375 {
            spacing = 0
            itemWidth = 28
            inset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
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
        setProfilePicture(image: KDriveResourcesAsset.placeholderAvatar.image)

        accountManager.currentAccount?.user?.getAvatar { image in
            self.setProfilePicture(image: image)
        }

        tabBar.tabDelegate = self
    }

    private func setProfilePicture(image: UIImage) {
        guard tabBar.items != nil && tabBar.items!.count > 4 else {
            return
        }

        let iconSize = 28.0

        tabBar.items![4].selectedImage = image
            .resize(size: CGSize(width: iconSize + 2, height: iconSize + 2))
            .maskImageWithRoundedRect(cornerRadius: CGFloat((iconSize + 2) / 2), borderWidth: 2, borderColor: KDriveResourcesAsset.infomaniakColor.color)
            .withRenderingMode(.alwaysOriginal)

        tabBar.items![4].image = image
            .resize(size: CGSize(width: iconSize, height: iconSize))
            .maskImageWithRoundedRect(cornerRadius: CGFloat(iconSize / 2), borderWidth: 0, borderColor: nil)
            .withRenderingMode(.alwaysOriginal)
    }

    func plusButtonPressed() {
        let (currentDriveFileManager, currentDirectory) = getCurrentDirectory()
        let floatingPanelViewController = AdaptiveDriveFloatingPanelController()
        let fromFileList = (selectedViewController as? UINavigationController)?.topViewController as? FileListViewController != nil
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

    func getCurrentDirectory() -> (DriveFileManager, File) {
        if let filesViewController = (selectedViewController as? UINavigationController)?.topViewController as? FileListViewController,
           let driveFileManager = filesViewController.driveFileManager,
           filesViewController.viewModel.currentDirectory.id >= DriveFileManager.constants.rootID {
            return (driveFileManager, filesViewController.viewModel.currentDirectory)
        } else {
            let file = driveFileManager.getCachedRootFile()
            return (driveFileManager, file)
        }
    }

    func enableCenterButton(isEnabled: Bool) {
        tabBar.centerButton?.isEnabled = isEnabled
    }

    func enableCenterButton(from file: File) {
        enableCenterButton(isEnabled: file.capabilities.canCreateFile)
    }

    private func setDriveFileManager(_ driveFileManager: DriveFileManager?, completion: (DriveFileManager) -> Void) {
        if let driveFileManager = driveFileManager {
            completion(driveFileManager)
        } else {
            if accountManager.drives.isEmpty {
                let driveErrorVC = DriveErrorViewController.instantiate()
                driveErrorVC.driveErrorViewType = .noDrive
                (UIApplication.shared.delegate as? AppDelegate)?.setRootViewController(UINavigationController(rootViewController: driveErrorVC))
            } else {
                // Invalid token or unknown error
                (UIApplication.shared.delegate as? AppDelegate)?.setRootViewController(SwitchUserViewController.instantiateInNavigationController())
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorDisconnected)
            }
        }
    }

    class func instantiate() -> MainTabViewController {
        return Storyboard.main.instantiateViewController(withIdentifier: "MainTabViewController") as! MainTabViewController
    }
}

// MARK: - Tab bar controller delegate

extension MainTabViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if let homeViewController = (viewController as? UINavigationController)?.topViewController as? HomeViewController {
            homeViewController.presentedFromTabBar()
        }

        if tabBarController.selectedViewController == viewController, let viewController = (viewController as? UINavigationController)?.topViewController as? TopScrollable {
            viewController.scrollToTop()
        }

        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let (_, currentDirectory) = getCurrentDirectory()
        (tabBarController as? MainTabViewController)?.enableCenterButton(from: currentDirectory)
    }
}

// MARK: - SwitchAccountDelegate, SwitchDriveDelegate

extension MainTabViewController: SwitchAccountDelegate, SwitchDriveDelegate {
    func didUpdateCurrentAccountInformations(_ currentAccount: Account) {
        updateTabBarProfilePicture()
        for viewController in viewControllers ?? [] where viewController.isViewLoaded {
            ((viewController as? UINavigationController)?.viewControllers.first as? SwitchAccountDelegate)?.didUpdateCurrentAccountInformations(currentAccount)
        }
    }

    func didSwitchCurrentAccount(_ newAccount: Account) {
        updateTabBarProfilePicture()
        for viewController in viewControllers ?? [] where viewController.isViewLoaded {
            ((viewController as? UINavigationController)?.viewControllers.first as? SwitchAccountDelegate)?.didSwitchCurrentAccount(newAccount)
        }
        setDriveFileManager(accountManager.currentDriveFileManager) { currentDriveFileManager in
            self.didSwitchDriveFileManager(newDriveFileManager: currentDriveFileManager)
        }
    }

    func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
        driveFileManager = newDriveFileManager
        // Tell Files app that the drive changed
        DriveInfosManager.instance.getFileProviderManager(for: driveFileManager.drive) { manager in
            manager.signalEnumerator(for: .workingSet) { _ in }
            manager.signalEnumerator(for: .rootContainer) { _ in }
        }
        for viewController in viewControllers ?? [] {
            guard let switchDriveDelegate = (viewController as? UINavigationController)?.viewControllers.first as? UIViewController & SwitchDriveDelegate else { continue }
            if switchDriveDelegate.isViewLoaded {
                switchDriveDelegate.didSwitchDriveFileManager(newDriveFileManager: driveFileManager)
            } else {
                switchDriveDelegate.driveFileManager = driveFileManager
            }
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
                    uploadQueue.saveToRealmAndAddToQueue(uploadFile:
                        UploadFile(
                            parentDirectoryId: documentPicker.importDriveDirectory.id,
                            userId: accountManager.currentUserId,
                            driveId: documentPicker.importDrive.id,
                            url: targetURL,
                            name: url.lastPathComponent
                        ))
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
                }
            }
        }
    }
}
