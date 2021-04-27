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

protocol SelectedUsersDelegate: AnyObject {
    func didDeleteUser(user: DriveUser)
    func didDeleteMail(mail: String)
}

class InvitedUserTableViewCell: InsetTableViewCell {

    @IBOutlet weak var invitedCollectionView: UICollectionView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!

    weak var delegate: SelectedUsersDelegate?

    private var users: [DriveUser] = []
    private var mails: [String] = []
    private var labels: [String] = []
    private var cellWidth: CGFloat!

    override func awakeFromNib() {
        super.awakeFromNib()
        (invitedCollectionView.collectionViewLayout as! AlignedCollectionViewFlowLayout).horizontalAlignment = .leading
        invitedCollectionView.register(cellView: InvitedUserCollectionViewCell.self)
    }

    func configureWith(users: [DriveUser], mails: [String], tableViewWidth: CGFloat) {
        self.users = users
        self.mails = mails
        labels = users.map(\.displayName) + mails
        cellWidth = tableViewWidth - 48 - 8

        invitedCollectionView.reloadData()
        heightConstraint.constant = computeHeightForUsers()
    }

    private func sizeForCellWith(text: String) -> CGSize {
        let testSizeLabel = UILabel()
        testSizeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        testSizeLabel.numberOfLines = 1
        testSizeLabel.text = text
        testSizeLabel.sizeToFit()

        var width = 8 + 24 + 8 + testSizeLabel.bounds.width + 8 + 24 + 8
        width = width > cellWidth ? cellWidth : width
        let height = testSizeLabel.bounds.height + 27

        return CGSize(width: width, height: height)
    }

    private func computeHeightForUsers() -> CGFloat {
        var currentLineWidth: CGFloat = 0
        var height: CGFloat = 0
        for labelText in labels {
            let cellSize = sizeForCellWith(text: labelText)
            if height == 0 {
                currentLineWidth = cellSize.width
                height = cellSize.height + 8
            } else if currentLineWidth + cellSize.width < cellWidth {
                currentLineWidth += cellSize.width
            } else {
                currentLineWidth = cellSize.width
                height += cellSize.height + 8
            }
        }
        return height
    }


}
//MARK: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout
extension InvitedUserTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return users.count + mails.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: InvitedUserCollectionViewCell.self, for: indexPath)
        cell.widthConstraint.constant = sizeForCellWith(text: labels[indexPath.row]).width
        if indexPath.row < users.count {
            let user = users[indexPath.row]
            cell.usernameLabel.text = user.displayName
            user.getAvatar { (image) in
                cell.avatarImage.image = image
                    .resizeImage(size: CGSize(width: 35, height: 35))
                    .maskImageWithRoundedRect(cornerRadius: CGFloat(35 / 2), borderWidth: 0, borderColor: .clear)
                    .withRenderingMode(.alwaysOriginal)
            }
            cell.removeButtonHandler = { sender in
                self.delegate?.didDeleteUser(user: user)
            }
        } else {
            cell.usernameLabel.text = mails[indexPath.row - users.count]
            cell.avatarImage.image = KDriveAsset.circleSend.image
            cell.removeButtonHandler = { sender in
                self.delegate?.didDeleteMail(mail: self.mails[indexPath.row - self.users.count])
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return sizeForCellWith(text: labels[indexPath.item])
    }

}

