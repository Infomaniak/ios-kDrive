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

import InfomaniakLogin
import kDriveCore
import kDriveResources
import UIKit

class SwitchUserViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    let accountManager = AccountManager.instance

    var isRootViewController: Bool {
        if let navigationController = view.window?.rootViewController as? UINavigationController {
            return navigationController.visibleViewController == self
        } else {
            return view.window?.rootViewController == self
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        InfomaniakLogin.setupWebviewNavbar(title: "", titleColor: nil, color: nil, buttonColor: nil, clearCookie: true, timeOutMessage: "Timeout")
        tableView.register(cellView: UserAccountTableViewCell.self)
        // Try to update other accounts infos
        Task {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for account in accountManager.accounts where account != accountManager.currentAccount {
                    group.addTask {
                        _ = try await self.accountManager.updateUser(for: account, registerToken: false)
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setTransparentStandardAppearanceNavigationBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, "SwitchUser"])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setDefaultStandardAppearanceNavigationBar()
    }

    @IBAction func buttonAddUserClicked(_ sender: UIButton) {
        MatomoUtils.track(eventWithCategory: .account, name: "add")
        let nextViewController = OnboardingViewController.instantiate()
        nextViewController.addUser = true
        present(nextViewController, animated: true)
    }

    class func instantiate() -> SwitchUserViewController {
        return Storyboard.menu.instantiateViewController(withIdentifier: "SwitchUserViewController") as! SwitchUserViewController
    }

    class func instantiateInNavigationController() -> UINavigationController {
        let switchUserViewController = instantiate()
        let navigationController = UINavigationController(rootViewController: switchUserViewController)
        navigationController.setInfomaniakAppearanceNavigationBar()
        return navigationController
    }
}

// MARK: - Table view delegate

extension SwitchUserViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let account = accountManager.accounts[indexPath.row]

        if !account.isConnected {
            // Ask to reconnect
            InfomaniakLogin.webviewLoginFrom(viewController: self, delegate: self)
            return
        }

        let drives = DriveInfosManager.instance.getDrives(for: account.userId)
        if drives.count == 1 && drives[0].maintenance {
            let driveErrorViewControllerNav = DriveErrorViewController.instantiateInNavigationController()
            let driveErrorViewController = driveErrorViewControllerNav.viewControllers.first as? DriveErrorViewController
            driveErrorViewController?.driveErrorViewType = .maintenance
            driveErrorViewController?.driveName = drives[0].name
            tableView.deselectRow(at: indexPath, animated: true)
            present(driveErrorViewControllerNav, animated: true)
        } else {
            MatomoUtils.track(eventWithCategory: .account, name: "switch")
            MatomoUtils.connectUser()

            AccountManager.instance.switchAccount(newAccount: account)
            (UIApplication.shared.delegate as? AppDelegate)?.refreshCacheData(preload: true, isSwitching: true)
            if isRootViewController {
                (UIApplication.shared.delegate as? AppDelegate)?.setRootViewController(MainTabViewController.instantiate())
            } else {
                navigationController?.popViewController(animated: true)
            }
        }
    }
}

// MARK: - Table view data source

extension SwitchUserViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accountManager.accounts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let account = accountManager.accounts[indexPath.row]
        let cell = tableView.dequeueReusableCell(type: UserAccountTableViewCell.self, for: indexPath)
        cell.initWithPositionAndShadow(isFirst: true, isLast: true)
        cell.titleLabel.text = account.user.displayName
        cell.userEmailLabel.text = account.user.email
        cell.logoImage.image = KDriveResourcesAsset.placeholderAvatar.image
        cell.isUserInteractionEnabled = !DriveInfosManager.instance.getDrives(for: account.userId).isEmpty

        account.user.getAvatar { image in
            cell.logoImage.image = image
        }
        return cell
    }
}

// MARK: - Infomaniak login delegate

extension SwitchUserViewController: InfomaniakLoginDelegate {
    func didCompleteLoginWith(code: String, verifier: String) {
        Task {
            do {
                _ = try await AccountManager.instance.createAndSetCurrentAccount(code: code, codeVerifier: verifier)
                // Download root file
                Task {
                    _ = try await AccountManager.instance.currentDriveFileManager?.file(id: DriveFileManager.constants.rootID)
                    (UIApplication.shared.delegate as! AppDelegate).setRootViewController(MainTabViewController.instantiate())
                }
            } catch {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorConnection)
            }
        }
    }

    func didFailLoginWith(error: String) {
        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorConnection)
    }
}
