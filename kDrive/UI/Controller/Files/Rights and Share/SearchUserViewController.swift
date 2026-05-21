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

import InfomaniakCore
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

protocol SearchUserDelegate: AnyObject {
    func didSelect(shareable: Shareable)
    func didSelect(email: String)
}

class SearchUserViewController: UITableViewController {
    @LazyInjectService private var driveInfosManager: DriveInfosManager

    weak var delegate: SearchUserDelegate?

    var canUseTeam = false
    var ignoredEmails: [String] = []
    var ignoredShareables: [Shareable] = []

    private var shareables: [Shareable] = []
    private var results: [CellResult] = []

    private enum CellResult {
        case shareable(Shareable)
        case email(String)
    }

    var drive: Drive! {
        didSet {
            guard drive != nil else {
                return
            }

            let users = driveInfosManager.getUsers(for: drive.id, userId: drive.userId)
            shareables = users.sorted { $0.displayName < $1.displayName }
            if canUseTeam {
                let teams = driveInfosManager.getTeams(for: drive.id, userId: drive.userId)
                shareables = teams.sorted() + shareables
            }

            performSearch(query: "")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: UserAccountTableViewCell.self)
        tableView.backgroundColor = KDriveCoreAsset.backgroundColor.color
        tableView.separatorStyle = .none
    }

    func performSearch(query: String) {
        filterContent(for: standardize(text: query))
    }

    private func filterContent(for text: String) {
        var filtered: [Shareable]
        if text.isEmpty {
            filtered = shareables.filter { shareable in
                !ignoredShareables.contains { $0.id == shareable.id }
            }
        } else {
            filtered = shareables.filter { shareable in
                !ignoredShareables.contains { $0.id == shareable.id } &&
                    (shareable.displayName.lowercased().contains(text) ||
                        (shareable as? DriveUser)?.email.lowercased().contains(text) ?? false)
            }
        }

        results = filtered.map { .shareable($0) }

        if EmailChecker(email: text).validate(),
           !ignoredEmails.contains(text),
           !shareables.contains(where: { ($0 as? DriveUser)?.email.lowercased() == text }) {
            results.append(.email(text))
        }

        tableView.reloadData()
    }

    private func standardize(text: String) -> String {
        return text.trimmingCharacters(in: .whitespaces).lowercased()
    }

    override func tableView(_: UITableView, numberOfRowsInSection: Int) -> Int {
        return results.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: UserAccountTableViewCell.self, for: indexPath)
        cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == results.count - 1)
        cell.accessoryImageView.image = nil
        cell.logoImage.isAccessibilityElement = false

        switch results[indexPath.row] {
        case .shareable(let shareable):
            configureCellForShareable(cell, shareable: shareable)
        case .email(let email):
            configureCellForEmail(cell, email: email)
        }

        return cell
    }

    private func configureCellForShareable(_ cell: UserAccountTableViewCell, shareable: Shareable) {
        if let user = shareable as? DriveUser {
            cell.titleLabel.text = user.displayName
            cell.userEmailLabel.text = user.email
            user.getAvatar { image in
                cell.logoImage.image = image
                    .resize(size: CGSize(width: 35, height: 35))
                    .maskImageWithRoundedRect(cornerRadius: CGFloat(35 / 2), borderWidth: 0, borderColor: .clear)
                    .withRenderingMode(.alwaysOriginal)
            }
        } else if let team = shareable as? Team {
            cell.titleLabel.text = team.displayName
            cell.logoImage.image = team.icon
            if let usersCount = team.usersCount {
                cell.userEmailLabel.text = KDriveResourcesStrings.Localizable.shareUsersCount(usersCount)
            } else {
                cell.userEmailLabel.text = nil
            }
        }
    }

    private func configureCellForEmail(_ cell: UserAccountTableViewCell, email: String) {
        cell.titleLabel.text = email
        cell.userEmailLabel.text = KDriveResourcesStrings.Localizable.userInviteByEmail
        cell.logoImage.image = KDriveResourcesAsset.circleSend.image
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch results[indexPath.row] {
        case .shareable(let shareable):
            delegate?.didSelect(shareable: shareable)
        case .email(let email):
            delegate?.didSelect(email: email)
        }
    }
}
