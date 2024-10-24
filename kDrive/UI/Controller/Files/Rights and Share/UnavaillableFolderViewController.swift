/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

import kDriveResources
import UIKit

class UnavaillableFolderViewController: BaseInfoViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        centerImageView.image = KDriveResourcesAsset.ufo.image
        titleLabel.text = "Content Unavailable"
        descriptionLabel
            .text =
            "The link has been deactivated or has expired. To access the files, send a message to the user who shared the link with you to reactivate it."
    }
}
