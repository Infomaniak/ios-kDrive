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
import kDriveCore
import UIKit

protocol SearchUserDelegate: AnyObject {
    func didSelectUser(user: DriveUser)
    func didSelectEmail(email: String)
}

class InviteUserTableViewCell: InsetTableViewCell {
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var dropDownAnchorView: UIView!

    weak var delegate: SearchUserDelegate?
    let dropDown = DropDown()

    var removeUsers: [Int] = [] {
        didSet {
            filterContent(for: textField.text?.trimmingCharacters(in: .whitespaces) ?? "")
        }
    }
    var removeEmails: [String] = []

    private var users: [DriveUser] = []
    private var results: [DriveUser] = []
    private var email: String?

    var drive: Drive! {
        didSet {
            guard drive != nil else { return }
            users = DriveInfosManager.instance.getUsers(for: drive.id)
            users.sort { $0.displayName < $1.displayName }
            results = users.filter { !removeUsers.contains($0.id) }

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

        dropDown.customCellConfiguration = { index, _, cell in
            guard let cell = cell as? UsersDropDownTableViewCell else { return }
            if let email = self.email {
                if index == 0 {
                    cell.configureWith(mail: email)
                } else {
                    cell.configureWith(user: self.results[index - 1])
                }
            } else {
                cell.configureWith(user: self.results[index])
            }
        }
        dropDown.selectionAction = { [unowned self] index, _ in
            selectItem(at: index)
        }

        dropDown.dataSource = results.map(\.displayName)
    }

    @IBAction func editingDidChanged(_ sender: UITextField) {
        if let searchText = textField.text {
            filterContent(for: searchText.trimmingCharacters(in: .whitespaces))
        }
        dropDown.show()
    }

    private func filterContent(for text: String) {
        if text.isEmpty {
            // If no text, we return all users, except the one explicitly removed
            results = users.filter { !removeUsers.contains($0.id) }
        } else {
            // Filter the users based on the text
            results = users.filter { !removeUsers.contains($0.id) && ($0.displayName.contains(text) || $0.email.contains(text)) }
        }
        dropDown.dataSource.removeAll()
        if isValidEmail(text) && !removeEmails.contains(text) && !users.contains(where: { $0.email == text }) {
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
        if let email = email {
            if index == 0 {
                delegate?.didSelectEmail(email: email)
            } else {
                delegate?.didSelectUser(user: results[index - 1])
            }
        } else {
            delegate?.didSelectUser(user: results[index])
        }
        textField.text = ""
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
