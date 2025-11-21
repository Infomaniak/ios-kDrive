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

import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import InfomaniakLogin
import InfomaniakOnboarding
import kDriveCore
import kDriveResources
import UIKit

class SwitchUserViewController: UIViewController {
    @IBOutlet var tableView: UITableView!

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var driveInfosManager: DriveInfosManager
    @LazyInjectService var infomaniakLogin: InfomaniakLoginable
    @LazyInjectService var appNavigable: AppNavigable

    var isRootViewController: Bool {
        if let navigationController = view.window?.rootViewController as? UINavigationController {
            return navigationController.visibleViewController == self
        } else {
            return view.window?.rootViewController == self
        }
    }

    private var accounts = [Account]()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: UserAccountTableViewCell.self)

        accounts = accountManager.accounts.values

        // Try to update other accounts infos
        Task {
            try await accountManager.updateAccountsInfos()

            reloadDataSource()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setTransparentStandardAppearanceNavigationBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        matomo.track(view: [MatomoUtils.View.menu.displayName, "SwitchUser"])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setDefaultStandardAppearanceNavigationBar()
    }

    @IBAction func buttonAddUserClicked(_ sender: UIButton) {
        matomo.track(eventWithCategory: .account, name: "add")
        let nextViewController = WaveViewController(slides: Slide.pleaseLogin) { [weak self] in
            self?.dismiss(animated: true)
        }
        nextViewController.modalPresentationStyle = .fullScreen
        present(nextViewController, animated: true)
    }

    private func reloadDataSource() {
        accounts = accountManager.accounts.values
        tableView.reloadData()
    }

    private func switchToConnectedAccount(_ account: Account) {
        do {
            guard let existingAccount = accountManager.account(for: account.userId) else {
                reloadDataSource()
                return
            }

            let driveFileManager = try accountManager.getFirstAvailableDriveFileManager(for: existingAccount.userId)
            matomo.track(eventWithCategory: .account, name: "switch")
            matomo.connectUser(userId: account.userId.description)

            accountManager.switchAccount(newAccount: existingAccount)
            appNavigable.showMainViewController(driveFileManager: driveFileManager, selectedIndex: nil)
        } catch DriveError.NoDriveError.noDrive {
            let driveErrorNavigationViewController = DriveErrorViewController.instantiateInNavigationController(
                errorType: .noDrive,
                drive: nil
            )
            present(driveErrorNavigationViewController, animated: true)
        } catch DriveError.NoDriveError.blocked(let drive), DriveError.NoDriveError.maintenance(let drive) {
            let driveErrorNavigationViewController = DriveErrorViewController.instantiateInNavigationController(
                errorType: drive.isInTechnicalMaintenance ? .maintenance : .blocked,
                drive: drive
            )
            present(driveErrorNavigationViewController, animated: true)
        } catch {
            SentryDebug.logPreloadingAccountError(error: error, origin: "SwitchUserViewController")
            // Unknown error, remove the user
            accountManager.removeTokenAndAccount(account: account)
        }
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
        let account = accounts[indexPath.row]
        switchToConnectedAccount(account)
    }
}

// MARK: - Table view data source

extension SwitchUserViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let account = accounts[indexPath.row]
        let cell = tableView.dequeueReusableCell(type: UserAccountTableViewCell.self, for: indexPath)
        cell.initWithPositionAndShadow(isFirst: true, isLast: true)
        cell.titleLabel.text = account.user.displayName
        cell.userEmailLabel.text = account.user.email
        cell.logoImage.image = KDriveResourcesAsset.placeholderAvatar.image

        if account == accountManager.currentAccount {
            cell.accessoryImageView.image = KDriveResourcesAsset.check.image
            cell.isUserInteractionEnabled = false
        } else {
            cell.accessoryImageView.image = KDriveResourcesAsset.chevronRight.image
            cell.isUserInteractionEnabled = !driveInfosManager.getDrives(for: account.userId).isEmpty
        }

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
                let connectedAccount = try await accountManager.createAndSetCurrentAccount(code: code, codeVerifier: verifier)

                switchToConnectedAccount(connectedAccount)
            } catch {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorConnection)
            }
        }
    }

    func didFailLoginWith(error: Error) {
        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorConnection)
    }
}
