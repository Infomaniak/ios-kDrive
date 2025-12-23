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

import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class NewFolderShareRuleTableViewCell: InsetTableViewCell {
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var imageStackViewWidth: NSLayoutConstraint!
    @IBOutlet var descriptionLabel: UILabel!

    @LazyInjectService var accountManager: AccountManageable

    var rights = true
    var fileAccessElements = [FileAccessElement]()
    var plusUser = 0

    override func awakeFromNib() {
        super.awakeFromNib()
        rights = false
        collectionView.isHidden = true
        accessoryImageView.isHidden = false
        collectionView.register(cellView: NewFolderShareRuleUserCollectionViewCell.self)
        collectionView.delegate = self
        collectionView.dataSource = self
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        rights = false
        collectionView.isHidden = true
        accessoryImageView.isHidden = false
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            contentInsetView.borderWidth = 2
            contentInsetView.borderColor = KDriveResourcesAsset.infomaniakColor.color
        } else {
            contentInsetView.borderWidth = 0
        }
    }

    func configureMeOnly() {
        titleLabel.text = KDriveResourcesStrings.Localizable.createFolderMeOnly
        descriptionLabel.isHidden = true
        imageStackViewWidth.constant = 30
        accessoryImageView.image = KDriveResourcesAsset.placeholderAvatar.image
        accessoryImageView.layer.cornerRadius = accessoryImageView.bounds.width / 2

        Task {
            let avatar = await accountManager.getCurrentUser()?.getAvatar()
            accessoryImageView.image = avatar
        }
    }

    func configureParentsRights(folderName: String, fileAccess: FileAccess?) {
        rights = true
        if let fileAccess {
            fileAccessElements = fileAccess.teams + fileAccess.users
        } else {
            fileAccessElements = []
        }

        if fileAccessElements.count > 3 {
            plusUser = fileAccessElements.count - 3
        }
        imageStackViewWidth.constant = 30
        accessoryImageView.isHidden = true
        collectionView.isHidden = false
        collectionView.reloadData()
        titleLabel.text = KDriveResourcesStrings.Localizable.createFolderKeepParentsRightTitle
        descriptionLabel.text = KDriveResourcesStrings.Localizable.createFolderKeepParentsRightDescription(folderName)
    }

    func configureSomeUser() {
        rights = false
        imageStackViewWidth.constant = 24
        accessoryImageView.image = KDriveResourcesAsset.users.image
        accessoryImageView.tintColor = KDriveResourcesAsset.iconColor.color
        titleLabel.text = KDriveResourcesStrings.Localizable.createFolderSomeUsersTitle
        descriptionLabel.text = KDriveResourcesStrings.Localizable.createFolderSomeUsersDescription
    }

    func configureAllUsers(driveName: String) {
        imageStackViewWidth.constant = 24
        accessoryImageView.image = KDriveResourcesAsset.drive.image
        accessoryImageView.tintColor = KDriveResourcesAsset.blueFolderColor.color
        titleLabel.text = KDriveResourcesStrings.Localizable.allAllDriveUsers
        descriptionLabel.text = KDriveResourcesStrings.Localizable.createCommonFolderAllUsersDescription(driveName)
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource

extension NewFolderShareRuleTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if rights {
            return plusUser == 0 ? fileAccessElements.count : 3
        }
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: NewFolderShareRuleUserCollectionViewCell.self, for: indexPath)
        if plusUser == 0 {
            cell.configure(with: fileAccessElements[indexPath.row])
        } else {
            if indexPath.row == 2 {
                cell.configureWith(moreValue: plusUser)
            } else {
                cell.configure(with: fileAccessElements[indexPath.row])
            }
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension NewFolderShareRuleTableViewCell: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return CGSize(width: 30, height: 30)
    }
}
