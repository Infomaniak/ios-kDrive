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

import InfomaniakCore
import kDriveCore
import kDriveResources
import UIKit

protocol FileDetailDelegate: AnyObject {
    func didUpdateSegmentedControl(value: Int)
}

class FileDetailHeaderTableViewCell: UITableViewCell {
    @IBOutlet var segmentedControl: IKSegmentedControl!
    @IBOutlet var fileNameLabel: UILabel!
    @IBOutlet var fileDetailLabel: UILabel!
    @IBOutlet var fileImage: UIImageView!
    @IBOutlet var fileImageView: UIView!
    @IBOutlet var darkLayer: UIView!

    weak var delegate: FileDetailDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        fileImageView.cornerRadius = 15
        fileImageView.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        resetSegmentedControl()
    }

    private func resetSegmentedControl() {
        segmentedControl.setSegments([
            KDriveResourcesStrings.Localizable.fileDetailsInfosTitle,
            KDriveResourcesStrings.Localizable.fileDetailsActivitiesTitle,
            KDriveResourcesStrings.Localizable.fileDetailsCommentsTitle
        ])
    }

    @IBAction func segmentedControlUpdated(_ sender: UISegmentedControl) {
        delegate?.didUpdateSegmentedControl(value: sender.selectedSegmentIndex)
    }

    func configureWith(file: File) {
        fileNameLabel.text = file.name
        fileDetailLabel.text = file.getFileSize()! + " • " + Constants.formatFileLastModifiedDate(file.lastModifiedAt)
        darkLayer.isHidden = true

        fileNameLabel.textColor = .white
        fileDetailLabel.textColor = .white
        fileImage.image = nil
        fileImage.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color
        file.getThumbnail { image, _ in
            self.fileImage.image = image
            self.fileImage.backgroundColor = nil
            self.darkLayer.isHidden = false
        }
    }
}
