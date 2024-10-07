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
import kDriveCore
import kDriveResources
import UIKit

protocol FileUsersDelegate: AnyObject {
    func shareButtonTapped()
}

class FileInformationUsersTableViewCell: UITableViewCell {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var shareButton: ImageButton!

    var fileAccessElements = [FileAccessElement]()
    weak var delegate: FileUsersDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(cellView: FileDetailInformationUserCollectionViewCell.self)
        shareButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonFileRights
    }

    @IBAction func shareButtonTapped(_ sender: Any) {
        delegate?.shareButtonTapped()
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout

extension FileInformationUsersTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fileAccessElements.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: FileDetailInformationUserCollectionViewCell.self, for: indexPath)
        cell.configureWith(moreValue: 0, fileAccessElement: fileAccessElements[indexPath.row])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return CGSize(width: 35, height: 35)
    }
}
