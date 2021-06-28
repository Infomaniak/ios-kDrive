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

protocol FileDetailDelegate: AnyObject {
    func didUpdateSegmentedControl(value: Int)
}

class FileDetailHeaderTableViewCell: UITableViewCell {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var fileDetailLabel: UILabel!
    @IBOutlet weak var fileImage: UIImageView!
    @IBOutlet weak var fileImageView: UIView!
    @IBOutlet weak var darkLayer: UIView!

    weak var delegate: FileDetailDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        fileImageView.cornerRadius = 15
        fileImageView.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        var size: CGFloat = 14
        if UIScreen.main.bounds.width < 390 {
            size = ceil(size * UIScreen.main.bounds.width / 390)
        }
        let font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: size))
        segmentedControl.setTitleTextAttributes([.foregroundColor: KDriveAsset.disconnectColor.color, .font: font], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: font], for: .selected)
        resetSegmentedControl()
    }

    private func resetSegmentedControl() {
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: KDriveStrings.Localizable.fileDetailsInfosTitle, at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: KDriveStrings.Localizable.fileDetailsActivitiesTitle, at: 1, animated: false)
        segmentedControl.insertSegment(withTitle: KDriveStrings.Localizable.fileDetailsCommentsTitle, at: 2, animated: false)
        segmentedControl.selectedSegmentIndex = 0
    }

    @IBAction func segmentedControlUpdated(_ sender: UISegmentedControl) {
        delegate?.didUpdateSegmentedControl(value: sender.selectedSegmentIndex)
    }

    func configureWith(file: File) {
        fileNameLabel.text = file.name
        fileDetailLabel.text = file.getFileSize() + " • " + Constants.formatFileLastModifiedDate(file.lastModifiedDate)
        darkLayer.isHidden = true

        fileNameLabel.textColor = .white
        fileDetailLabel.textColor = .white
        fileImage.image = nil
        fileImage.backgroundColor = KDriveAsset.loaderDarkerDefaultColor.color
        file.getThumbnail { image, _ in
            self.fileImage.image = image
            self.fileImage.backgroundColor = nil
            self.darkLayer.isHidden = false
        }
    }
}
