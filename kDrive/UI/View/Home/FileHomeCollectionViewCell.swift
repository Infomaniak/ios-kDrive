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

import InfomaniakCoreUI
import kDriveCore
import kDriveResources
import UIKit

final class FileHomeCollectionViewCell: FileGridCollectionViewCell {
    @IBOutlet weak var timeStackView: UIStackView!
    @IBOutlet weak var timeLabel: IKLabel!

    override var checkmarkImage: UIImageView? {
        return nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        timeLabel.text = ""
        timeStackView.isHidden = false
    }

    override func configureWith(driveFileManager: DriveFileManager, file: File, selectionMode: Bool = false) {
        super.configureWith(driveFileManager: driveFileManager, file: file, selectionMode: selectionMode)
        timeLabel.text = Constants.formatDate(file.lastModifiedAt, style: .dateTime, relative: true)
    }

    override func configureLoading() {
        super.configureLoading()
        timeStackView.isHidden = true
    }
}
