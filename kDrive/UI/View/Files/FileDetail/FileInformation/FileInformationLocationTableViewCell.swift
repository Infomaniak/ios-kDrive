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

protocol FileLocationDelegate: AnyObject {
    func locationButtonTapped()
}

class FileInformationLocationTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var locationImage: UIImageView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var locationButton: UIButton!

    weak var delegate: FileLocationDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        locationButton.accessibilityLabel = KDriveStrings.Localizable.allPathTitle
    }

    @IBAction func locationButtonTapped(_ sender: Any) {
        delegate?.locationButtonTapped()
    }

}
