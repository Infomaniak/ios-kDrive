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
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class SharedDrivesViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    @LazyInjectService private var accountManager: AccountManageable
    @LazyInjectService private var driveInfosManager: DriveInfosManager

    var drives: [Drive?] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = KDriveResourcesStrings.Localizable.sharedWithMeTitle
        tableView.register(cellView: MenuTableViewCell.self)

        navigationItem.hideBackButtonText()

        drives = driveInfosManager.getDrives(for: accountManager.currentUserId, sharedWithMe: true)
        showEmptyView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedPath, animated: true)
        }
        (tabBarController as? MainTabViewController)?.enableCenterButton(isEnabled: false)
    }

    private func showEmptyView() {
        if drives.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
            let background = EmptyTableView.instantiate(type: .noNetwork, button: true)
            background.actionHandler = { [weak self] _ in
                self?.tableView.reloadData()
            }
            tableView.backgroundView = background
        } else if drives.isEmpty {
            let background = EmptyTableView.instantiate(type: .noSharedWithMe)
            tableView.backgroundView = background
        } else {
            tableView.backgroundView = nil
        }
    }

    static func instantiate() -> SharedDrivesViewController {
        let viewController = Storyboard.menu
            .instantiateViewController(withIdentifier: "SharedDrivesViewController") as! SharedDrivesViewController
        return viewController
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension SharedDrivesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return drives.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: MenuTableViewCell.self, for: indexPath)
        cell.initWithPositionAndShadow(isFirst: true, isLast: true)
        cell.titleLabel.text = drives[indexPath.row]?.name
        cell.logoImage.image = KDriveResourcesAsset.drive.image
        cell.logoImage.tintColor = UIColor(hex: (drives[indexPath.row]?.preferences.color)!)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let drive = drives[indexPath.row] else {
            return
        }
        if drive.inMaintenance {
            let driveFloatingPanelController = DriveMaintenanceFloatingPanelViewController.instantiatePanel(drive: drive)
            tableView.deselectRow(at: indexPath, animated: true)
            present(driveFloatingPanelController, animated: true)
        } else if let driveFileManager = accountManager.getDriveFileManager(for: drive) {
            let viewModel = SharedWithMeViewModel(driveFileManager: driveFileManager, currentDirectory: nil)
            let fileListViewController = FileListViewController.instantiate(viewModel: viewModel)
            navigationController?.pushViewController(fileListViewController, animated: true)
        } else {
            UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
        }
    }
}
