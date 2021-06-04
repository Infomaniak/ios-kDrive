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
import kDriveCore

class SwitchDriveViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    private var drives = AccountManager.instance.drives
    private var filteredDrives: [Drive]!
    private let searchController = UISearchController(searchResultsController: nil)
    weak var delegate: SwitchDriveDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        filteredDrives = drives
        let accountManager = AccountManager.instance
        accountManager.updateUserForAccount(accountManager.currentAccount) { _, _, error in
            if error == nil {
                self.drives = accountManager.drives
                self.filteredDrives = self.drives
                self.tableView.reloadData()
            }
        }
        tableView.register(cellView: DriveSwitchTableViewCell.self)
        navigationController?.setTransparentStandardAppearanceNavigationBar()

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        definesPresentationContext = true
        navigationItem.searchController = searchController
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        navigationController?.navigationBar.layoutMargins.left = 24
        navigationController?.navigationBar.layoutMargins.right = 24

        if let textfield = searchController.searchBar.value(forKey: "searchField") as? UITextField {
            textfield.textColor = KDriveAsset.titleColor.color
            textfield.backgroundColor = KDriveAsset.backgroundColor.color
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTapToDismiss(_:)))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)

        let backgroundBlureView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        backgroundBlureView.alpha = 0.8
        tableView.backgroundView = backgroundBlureView
    }

    @objc func handleTapToDismiss(_ sender: UITapGestureRecognizer? = nil) {
        if let point = sender?.location(in: tableView),
            tableView.indexPathForRow(at: point) == nil {
            dismiss(animated: true)
        }
    }

    class func instantiate() -> SwitchDriveViewController {
        return UIStoryboard(name: "Home", bundle: nil).instantiateViewController(withIdentifier: "SwitchDriveViewController") as! SwitchDriveViewController
    }

}

// MARK: - UITableViewDelegate
extension SwitchDriveViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let drive = filteredDrives[indexPath.row]
        if drive.maintenance {
            let maintenanceFloatingPanelViewController = DriveMaintenanceFloatingPanelViewController.instantiatePanel()
            (maintenanceFloatingPanelViewController.contentViewController as? DriveMaintenanceFloatingPanelViewController)?.setTitleLabel(with: drive.name)
            self.present(maintenanceFloatingPanelViewController, animated: true)
        } else {
            AccountManager.instance.setCurrentDriveForCurrentAccount(drive: drive)
            AccountManager.instance.saveAccounts()
            // Download root file
            guard let currentDriveFileManager = AccountManager.instance.currentDriveFileManager else {
                return
            }

            currentDriveFileManager.getFile(id: DriveFileManager.constants.rootID) { _, _, _ in
                self.delegate?.didSwitchDriveFileManager(newDriveFileManager: currentDriveFileManager)
                self.dismiss(animated: true)
            }
        }
    }

}

// MARK: - UITableViewDataSource
extension SwitchDriveViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredDrives.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: DriveSwitchTableViewCell.self, for: indexPath)
        cell.initWithPositionAndShadow(isFirst: true, isLast: true)
        let drive = filteredDrives[indexPath.row]
        cell.configureWith(drive: drive)

        return cell
    }

}

// MARK: - UISearchResultsUpdating
extension SwitchDriveViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        if let text = searchController.searchBar.text {
            filterOrganisationsWithText(text)
        }
    }

    func filterOrganisationsWithText(_ text: String) {
        if !text.isEmpty {
            filteredDrives = drives.filter { $0.name.lowercased().contains(text.lowercased()) }
        } else {
            filteredDrives = drives
        }
        tableView.reloadData()
    }

}
