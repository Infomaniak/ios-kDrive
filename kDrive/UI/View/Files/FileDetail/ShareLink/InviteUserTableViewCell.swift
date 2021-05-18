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
import kDriveCore
import DropDown

protocol SearchUserDelegate: AnyObject {
    func didSelectUser(user: DriveUser)
    func didSelectMail(mail: String)
}

class InviteUserTableViewCell: InsetTableViewCell {

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var dropDownAnchorView: UIView!

    weak var delegate: SearchUserDelegate?
    let dropDown = DropDown()

    var removeUsers: [Int] = [] {
        didSet {
            guard drive != nil else { return }
            users = DriveInfosManager.instance.getUsers(for: drive.id)
            users.removeAll {
                $0.id == AccountManager.instance.currentAccount.user.id ||
                    removeUsers.contains($0.id)
            }
            filterContent(for: "")
        }
    }
    var removeEmails: [String] = []

    private var users: [DriveUser] = []
    private var results: [DriveUser] = []
    private var mail: String?

    var drive: Drive! {
        didSet {
            guard drive != nil else { return }
            users = DriveInfosManager.instance.getUsers(for: drive.id)
            users.sort { (user1, user2) -> Bool in
                return user1.displayName < user2.displayName
            }
            results = users

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

        dropDown.customCellConfiguration = { (index: Index, item: String, cell: DropDownCell) -> Void in
            guard let cell = cell as? UsersDropDownTableViewCell else { return }
            if let mail = self.mail {
                if index == 0 {
                    cell.configureWith(mail: mail)
                } else {
                    cell.configureWith(user: self.results[index - 1])
                }
            } else {
                cell.configureWith(user: self.results[index])
            }
        }
        dropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            if let mail = mail {
                if index == 0 {
                    delegate?.didSelectMail(mail: mail)
                } else {
                    delegate?.didSelectUser(user: results[index - 1])
                }
            } else {
                delegate?.didSelectUser(user: results[index])
            }
            textField.text = ""
        }

        dropDown.dataSource = results.map(\.displayName)
    }

    @IBAction func editingDidChanged(_ sender: UITextField) {
        if let searchText = textField.text {
            filterContent(for: searchText)
        }
        dropDown.show()
    }

    private func filterContent(for text: String) {
        var emailExist: Bool = false
        if text.count > 0 {
            results.removeAll()
            for user in users {
                if user.displayName.contains(text) || user.email.contains(text) {
                    results.append(user)
                    if text == user.email {
                        emailExist = true
                    }
                }
            }
        } else {
            results = users
        }
        dropDown.dataSource.removeAll()
        if isValidEmail(text) && !emailExist && !removeEmails.contains(text) {
            mail = text
            dropDown.dataSource.append(text)
        } else {
            mail = nil
        }
        dropDown.dataSource.append(contentsOf: results.map(\.displayName))
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailPred = NSPredicate(format: "SELF MATCHES %@", Constants.mailRegex)
        return emailPred.evaluate(with: email)
    }
}

// MARK: - UITextFieldDelegate
extension InviteUserTableViewCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        dropDown.setupCornerRadius(UIConstants.cornerRadius)
        dropDown.show()
    }
}

