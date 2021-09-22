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

import kDriveCore
import UIKit

class FileDetailHeaderAltTableViewCell: UITableViewCell {
    @IBOutlet weak var fileView: UIView!
    @IBOutlet weak var logoImage: UIImageView!
    @IBOutlet weak var logoContainerView: UIView!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var fileDetailLabel: UILabel!
    @IBOutlet weak var segmentedControl: IKSegmentedControl!

    weak var delegate: FileDetailDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        fileView.cornerRadius = 15
        fileView.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        logoContainerView.cornerRadius = logoContainerView.frame.width / 2
        resetSegmentedControl()
    }

    private func resetSegmentedControl() {
        segmentedControl.setSegments([KDriveStrings.Localizable.fileDetailsInfosTitle, KDriveStrings.Localizable.fileDetailsActivitiesTitle, KDriveStrings.Localizable.fileDetailsCommentsTitle])
    }

    @IBAction func segmentedControlUpdated(_ sender: UISegmentedControl) {
        delegate?.didUpdateSegmentedControl(value: sender.selectedSegmentIndex)
    }

    func configureWith(file: File) {
        fileNameLabel.text = file.name
        fileDetailLabel.text = Constants.formatFileLastModifiedDate(file.lastModifiedDate)
        logoImage.image = file.icon

        if file.isDirectory {
            segmentedControl.removeSegment(at: 2, animated: false)
        }
    }
}
