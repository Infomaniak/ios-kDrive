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

import UIKit
import InfomaniakCore
import FloatingPanel
import kDriveCore

class MainTabViewController: UITabBarController, MainTabBarDelegate {

    var floatingPanelViewController: DriveFloatingPanelController?

    var photoPickerDelegate = PhotoPickerDelegate()

    override var tabBar: MainTabBar {
        return super.tabBar as! MainTabBar
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.backgroundColor = KDriveAsset.backgroundCardViewColor.color
        delegate = self
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
        tabBar.items?[0].accessibilityLabel = KDriveStrings.Localizable.homeTitle
        tabBar.items?[1].accessibilityLabel = KDriveStrings.Localizable.fileListTitle
        tabBar.items?[3].accessibilityLabel = KDriveStrings.Localizable.favoritesTitle
        tabBar.items?[4].accessibilityLabel = KDriveStrings.Localizable.menuTitle
    }

    private func configureTabBar() {
        var spacing: CGFloat
        var itemWidth: CGFloat
        var inset: UIEdgeInsets

        if view.frame.width < 375 {
            spacing = 0
            itemWidth = 28
            if #available(iOS 13, *) {
                inset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            } else {
                //Hack to properly center icons < iOS 13
                inset = UIEdgeInsets(top: 0, left: 0, bottom: -8, right: 0)
            }
        } else {
            spacing = 35
            itemWidth = 35
            if #available(iOS 13, *) {
                inset = UIEdgeInsets(top: -2, left: -2, bottom: -2, right: -2)
            } else {
                //Hack to properly center icons < iOS 13
                inset = UIEdgeInsets(top: -2, left: -2, bottom: -10, right: -2)
            }
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
        setProfilePicture(image: KDriveAsset.placeholderAvatar.image)

        AccountManager.instance.currentAccount?.user?.getAvatar { (image) in
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
            .resizeImage(size: CGSize(width: iconSize + 2, height: iconSize + 2))
            .maskImageWithRoundedRect(cornerRadius: CGFloat((iconSize + 2) / 2), borderWidth: 1, borderColor: KDriveAsset.infomaniakColor.color)
            .withRenderingMode(.alwaysOriginal)

        tabBar.items![4].image = image
            .resizeImage(size: CGSize(width: iconSize, height: iconSize))
            .maskImageWithRoundedRect(cornerRadius: CGFloat(iconSize / 2), borderWidth: 0, borderColor: nil)
            .withRenderingMode(.alwaysOriginal)
    }

    func plusButtonPressed() {
        getCurrentDirectory() { file in
            if let currentDirectory = file {
                let floatingPanelViewController = DriveFloatingPanelController()
                let fileInformationsViewController = PlusButtonFloatingPanelViewController()
                fileInformationsViewController.currentDirectory = currentDirectory
                floatingPanelViewController.isRemovalInteractionEnabled = true
                floatingPanelViewController.delegate = fileInformationsViewController

                floatingPanelViewController.set(contentViewController: fileInformationsViewController)
                floatingPanelViewController.track(scrollView: fileInformationsViewController.tableView)
                self.present(floatingPanelViewController, animated: true)
            }
        }
    }

    func getCurrentDirectory(completion: @escaping (File?) -> Void) {
        if let filesViewController = (selectedViewController as? UINavigationController)?.topViewController as? FileListCollectionViewController {
            completion(filesViewController.currentDirectory)
        } else {
            AccountManager.instance.currentDriveFileManager.getFile(id: DriveFileManager.constants.rootID) { (file, children, error) in
                completion(file)
            }
        }
    }

    class func instantiate() -> MainTabViewController {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MainTabViewController") as! MainTabViewController
    }
}

// MARK: - Tab bar controller delegate
extension MainTabViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if let homeViewController = (viewController as? UINavigationController)?.topViewController as? HomeTableViewController {
            homeViewController.presentedFromTabBar()
        }

        if tabBarController.selectedViewController == viewController, let viewController = (viewController as? UINavigationController)?.topViewController as? TopScrollable {
            viewController.scrollToTop()
        }

        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        getCurrentDirectory { currentDirectory in
            (tabBarController as? MainTabViewController)?.tabBar.centerButton.isEnabled = currentDirectory?.rights?.createNewFile.value ?? true
        }
    }
}

// MARK: - SwitchAccountDelegate, SwitchDriveDelegate
extension MainTabViewController: SwitchAccountDelegate, SwitchDriveDelegate {

    func didUpdateCurrentAccountInformations(_ currentAccount: Account) {
        updateTabBarProfilePicture()
        for viewController in viewControllers ?? [] {
            if viewController.isViewLoaded {
                ((viewController as? UINavigationController)?.viewControllers.first as? SwitchAccountDelegate)?.didUpdateCurrentAccountInformations(currentAccount)
            }
        }
    }

    func didSwitchCurrentAccount(_ newAccount: Account) {
        updateTabBarProfilePicture()
        for viewController in viewControllers ?? [] {
            if viewController.isViewLoaded {
                ((viewController as? UINavigationController)?.viewControllers.first as? SwitchAccountDelegate)?.didSwitchCurrentAccount(newAccount)
            }
        }
        didSwitchDrive(newDrive: AccountManager.instance.currentDriveFileManager.drive)
    }

    func didSwitchDrive(newDrive: Drive) {
        //Tell Files app that the drive changed
        NSFileProviderManager.default.signalEnumerator(for: .workingSet) { (_) in }
        NSFileProviderManager.default.signalEnumerator(for: .rootContainer) { (_) in }
        for viewController in viewControllers ?? [] {
            if viewController.isViewLoaded {
                ((viewController as? UINavigationController)?.viewControllers.first as? SwitchDriveDelegate)?.didSwitchDrive(newDrive: newDrive)
            }
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension MainTabViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let documentPicker = controller as? DriveImportDocumentPickerViewController {
            for url in urls {
                UploadQueue.instance.addToQueue(file:
                        UploadFile(
                        parentDirectoryId: documentPicker.importDriveDirectory.id,
                        userId: AccountManager.instance.currentAccount.userId,
                        driveId: AccountManager.instance.currentDriveFileManager.drive.id,
                        url: url))
            }
        }
    }
}

