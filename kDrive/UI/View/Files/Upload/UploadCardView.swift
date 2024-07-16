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

import kDriveResources
import UIKit

class UploadCardView: UIView {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var cancelButton: UIButton?
    @IBOutlet var retryButton: UIButton?
    @IBOutlet var editImage: UIImageView?
    @IBOutlet var detailsLabel: UILabel!
    @IBOutlet var iconView: UIImageView!
    @IBOutlet var progressView: RPCircularProgress!
    @IBOutlet var iconViewHeightConstraint: NSLayoutConstraint!
    var cancelButtonPressedHandler: (() -> Void)?
    var retryButtonPressedHandler: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        retryButton?.addTarget(self, action: #selector(retryButtonPressed), for: .touchUpInside)
        cancelButton?.addTarget(self, action: #selector(cancelButtonPressed), for: .touchUpInside)
    }

    func setUploadCount(_ count: Int) {
        detailsLabel.text = KDriveResourcesStrings.Localizable.uploadInProgressNumberFile(count)
    }

    @objc private func retryButtonPressed() {
        retryButtonPressedHandler?()
    }

    @objc private func cancelButtonPressed() {
        cancelButtonPressedHandler?()
    }
}
