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
import InfomaniakCoreUI
import InfomaniakDI
import kDriveCore
import UIKit

protocol SearchUserDelegate: AnyObject {
    func didSelect(shareable: Shareable)
    func didSelect(email: String)
}

class InviteUserTableViewCell: InsetTableViewCell {
    @LazyInjectService private var driveInfosManager: DriveInfosManager

    @IBOutlet var textField: UITextField!
    @IBOutlet var dropDownAnchorView: UIView!

    weak var delegate: SearchUserDelegate?
    let dropDown = DropDown()

    var canUseTeam = false
    var ignoredEmails: [String] = []
    var ignoredShareables: [Shareable] = [] {
        didSet {
            filterContent(for: standardize(text: textField.text ?? ""))
        }
    }

    private var shareables: [Shareable] = []
    private var results: [Shareable] = []
    private var email: String?

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

            results = shareables.filter { shareable in
                !ignoredShareables.contains { $0.id == shareable.id }
            }

            configureDropDown()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        textField.delegate = self
    }

    func configureDropDown() {
        dropDown.anchorView = dropDownAnchorView
        dropDown.cellHeight = 65
        dropDown.cellNib = UINib(nibName: "UsersDropDownTableViewCell", bundle: nil)

        dropDown.customCellConfiguration = { [weak self] index, _, cell in
            guard let self else { return }
            guard let cell = cell as? UsersDropDownTableViewCell else { return }
            if let email {
                if index == 0 {
                    cell.configure(with: email)
                } else {
                    cell.configure(with: results[index - 1], drive: drive)
                }
            } else {
                cell.configure(with: results[index], drive: drive)
            }
        }
        dropDown.selectionAction = { [weak self] index, _ in
            guard let self else { return }
            selectItem(at: index)
        }

        dropDown.dataSource = results.map(\.displayName)
    }

    @IBAction func editingDidChanged(_ sender: UITextField) {
        if let searchText = textField.text {
            filterContent(for: standardize(text: searchText))
        }
        dropDown.show()
    }

    private func filterContent(for text: String) {
        if text.isEmpty {
            // If no text, we return all users, except the one explicitly removed
            results = shareables.filter { shareable in
                !ignoredShareables.contains { $0.id == shareable.id }
            }
        } else {
            // Filter the users based on the text
            results = shareables.filter { shareable in
                !ignoredShareables
                    .contains { $0.id == shareable.id } &&
                    (shareable.displayName.lowercased().contains(text) || (shareable as? DriveUser)?.email
                        .contains(text) ?? false)
            }
        }
        dropDown.dataSource.removeAll()
        if isValidEmail(text) && !ignoredEmails.contains(text) && !shareables
            .contains(where: { ($0 as? DriveUser)?.email == text }) {
            email = text
            dropDown.dataSource.append(text)
        } else {
            email = nil
        }
        dropDown.dataSource.append(contentsOf: results.map(\.displayName))
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailPred = NSPredicate(format: "SELF MATCHES %@", Constants.mailRegex)
        return emailPred.evaluate(with: email)
    }

    private func selectItem(at index: Int) {
        textField.text = ""
        if let email {
            if index == 0 {
                delegate?.didSelect(email: email)
            } else {
                delegate?.didSelect(shareable: results[index - 1])
            }
        } else {
            delegate?.didSelect(shareable: results[index])
        }
    }

    private func standardize(text: String) -> String {
        return text.trimmingCharacters(in: .whitespaces).lowercased()
    }
}

// MARK: - UITextFieldDelegate

extension InviteUserTableViewCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        dropDown.setupCornerRadius(UIConstants.cornerRadius)
        dropDown.show()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Select first result on text field return
        if !results.isEmpty || email != nil {
            // Hide the dropdown to prevent UI glitches
            dropDown.hide()
            selectItem(at: 0)
            return true
        } else {
            return false
        }
    }
}
