/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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

import kDriveCore
import kDriveResources
import UIKit

final class SearchControllerManager: NSObject, UISearchControllerDelegate, UISearchResultsUpdating {
    weak var hostViewController: UIViewController?
    weak var hostTableView: UITableView?
    weak var delegate: SearchUserDelegate?
    var onDismiss: (() -> Void)?

    var searchUserViewController: SearchUserViewController!
    var searchController: UISearchController!

    func setup(in viewController: UIViewController,
               tableView: UITableView,
               file: File,
               driveFileManager: DriveFileManager,
               ignoredShareables: [Shareable],
               ignoredEmails: [String]) {
        hostViewController = viewController
        hostTableView = tableView

        searchUserViewController = SearchUserViewController()
        searchUserViewController.delegate = self

        searchController = UISearchController(searchResultsController: searchUserViewController)
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = true
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = KDriveResourcesStrings.Localizable.shareFileInputUserAndEmail

        configureSearchViewController(file: file, driveFileManager: driveFileManager,
                                      ignoredShareable: ignoredShareables, ignoredEmails: ignoredEmails)
    }

    func updateIgnoredUser(ignoredShareable: [Shareable], ignoredEmails: [String]) {
        searchUserViewController.ignoredShareables = ignoredShareable
        searchUserViewController.ignoredEmails = ignoredEmails
    }

    private func configureSearchViewController(file: File, driveFileManager: DriveFileManager,
                                               ignoredShareable: [Shareable], ignoredEmails: [String]) {
        searchUserViewController.canUseTeam = file.capabilities.canUseTeam
        searchUserViewController.drive = driveFileManager.drive
        updateIgnoredUser(ignoredShareable: ignoredShareable, ignoredEmails: ignoredEmails)
    }

    private func showSearch(cell: InviteUserTableViewCell) {
        hostTableView?.layoutIfNeeded()
        hostViewController?.navigationItem.searchController = searchController

        UIView.animate(withDuration: 0.1, animations: {
            self.hostViewController?.view.layoutIfNeeded()
            cell.transform = CGAffineTransform(translationX: 0, y: -50)
            cell.alpha = 0
        }, completion: { _ in
            self.searchController.searchBar.becomeFirstResponder()
        })
    }

    func willDismissSearchController(_: UISearchController) {
        DispatchQueue.main.async {
            UIView.performWithoutAnimation {
                self.onDismiss?()
                self.hostViewController?.navigationItem.searchController = nil
                self.hostViewController?.view.layoutIfNeeded()
                self.hostTableView?.layoutIfNeeded()
            }
        }
    }

    func didDismissSearchController(_: UISearchController) {
        let indexPath = IndexPath(row: 0, section: 0)
        guard let cell = hostTableView?.cellForRow(at: indexPath) else {
            hostViewController?.navigationItem.searchController = nil
            return
        }
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.1) {
                cell.transform = .identity
                cell.alpha = 1
            }
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        searchUserViewController.performSearch(query: searchController.searchBar.text ?? "")
    }
}

extension SearchControllerManager: InviteUserCellDelegate {
    func inviteUserCellDidTapSearch(cell: InviteUserTableViewCell) {
        showSearch(cell: cell)
    }
}

extension SearchControllerManager: SearchUserDelegate {
    func didSelect(shareable: Shareable) {
        delegate?.didSelect(shareable: shareable)
    }

    func didSelect(email: String) {
        delegate?.didSelect(email: email)
    }
}
