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

import DropDown
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import UIKit

protocol SelectDriveDelegate: AnyObject {
    func didSelectDrive(_ drive: Drive)
}

class SelectDriveViewController: UIViewController {
    @IBOutlet var tableView: UITableView!

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var driveInfosManager: DriveInfosManager
    @LazyInjectService private var matomo: MatomoUtils

    private var driveList: [Drive]!
    private var currentAccount: Account!
    private var accounts: [Account]!
    var selectedDrive: Drive?
    weak var delegate: SelectDriveDelegate?

    private enum Section {
        case noAccount
        case selectAccount
        case selectDrive
    }

    private var sections: [Section] = [.selectAccount, .selectDrive]
    private let dropDown = DropDown()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hideBackButtonText()

        tableView.register(cellView: NoAccountTableViewCell.self)
        tableView.register(cellView: DriveSwitchTableViewCell.self)
        tableView.register(cellView: UserAccountTableViewCell.self)

        DropDown.startListeningToKeyboard()

        var selectedAccount: Account?
        if let selectedUserId = selectedDrive?.userId {
            selectedAccount = accountManager.account(for: selectedUserId)
        }

        if let account = selectedAccount ?? accountManager.currentAccount {
            initForCurrentAccount(account)
            if !accounts.isEmpty {
                sections = [.selectAccount, .selectDrive]
            } else {
                sections = [.selectDrive]
            }
        } else {
            sections = [.noAccount]
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        matomo.track(view: [MatomoUtils.View.save.displayName, "SelectDrive"])
    }

    private func initForCurrentAccount(_ account: Account) {
        currentAccount = account
        accounts = accountManager.accounts.filter { $0.userId != account.userId }
        driveList = Array(driveInfosManager.getDrives(for: account.userId, sharedWithMe: nil))
        dropDown.dataSource = accounts.map(\.user.displayName)
    }

    func configureDropDownWith(selectUserCell: UserAccountTableViewCell) {
        dropDown.anchorView = selectUserCell.contentInsetView
        dropDown.bottomOffset = CGPoint(x: 0, y: (dropDown.anchorView?.plainView.bounds.height)!)
        dropDown.cellHeight = 65
        dropDown.cellNib = UINib(nibName: "UsersDropDownTableViewCell", bundle: nil)

        dropDown.customCellConfiguration = { [weak self] (index: Index, _: String, cell: DropDownCell) in
            guard let self else { return }
            guard let cell = cell as? UsersDropDownTableViewCell else { return }
            let account = accounts[index]
            cell.configureWith(account: account)
        }
        dropDown.selectionAction = { [weak self] (index: Int, _: String) in
            guard let self else { return }
            let account = accounts[index]
            initForCurrentAccount(account)
            tableView.reloadSections([0, 1], with: .fade)
        }
    }

    class func instantiate() -> SelectDriveViewController {
        return Storyboard.saveFile
            .instantiateViewController(withIdentifier: "SelectDriveViewController") as! SelectDriveViewController
    }
}

// MARK: - UITableViewDataSource

extension SelectDriveViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .selectAccount, .noAccount:
            return 1
        case .selectDrive:
            return driveList.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .noAccount:
            let cell = tableView.dequeueReusableCell(type: NoAccountTableViewCell.self, for: indexPath)
            return cell
        case .selectAccount:
            let cell = tableView.dequeueReusableCell(type: UserAccountTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.titleLabel.text = currentAccount.user.displayName
            cell.userEmailLabel.text = currentAccount.user.email
            if let user = currentAccount.user {
                user.getAvatar { image in
                    cell.logoImage.image = image
                }
            }
            configureDropDownWith(selectUserCell: cell)
            return cell
        case .selectDrive:
            let cell = tableView.dequeueReusableCell(type: DriveSwitchTableViewCell.self, for: indexPath)
            let drive = driveList[indexPath.row]
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.style = .selectDrive
            cell.configureWith(drive: drive)
            cell.selectDriveImageView.image = nil
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension SelectDriveViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .noAccount:
            break
        case .selectAccount:
            tableView.deselectRow(at: indexPath, animated: true)
            dropDown.setupCornerRadius(UIConstants.cornerRadius)
            dropDown.show()
        case .selectDrive:
            let drive = driveList[indexPath.row]
            delegate?.didSelectDrive(drive)
            if let navigationController {
                navigationController.popViewController(animated: true)
            } else {
                dismiss(animated: true)
            }
        }
    }
}
