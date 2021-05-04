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
import kDriveCore

class NoPreviewCollectionViewCell: UICollectionViewCell, DownloadProgressObserver {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var offlineView: UIStackView!
    @IBOutlet weak var progressView: UIProgressView!

    override func prepareForReuse() {
        super.prepareForReuse()
        progressView.isHidden = true
    }

    func configureWith(file: File, isOffline: Bool = false) {
        titleLabel.text = file.name
        if isOffline {
            iconImageView.image = KDriveAsset.fileDefault.image
            subtitleLabel.text = KDriveStrings.Localizable.previewLoadError
            offlineView.isHidden = false
        } else {
            iconImageView.image = file.icon
            subtitleLabel.text = KDriveStrings.Localizable.previewNoPreview
            offlineView.isHidden = true
        }
    }

    func setDownloadProgress(_ progress: Progress) {
        progressView.isHidden = false
        progressView.observedProgress = progress
        subtitleLabel.text = KDriveStrings.Localizable.previewDownloadIndication
    }

    func errorDownloading() {
        progressView.isHidden = true
        subtitleLabel.text = KDriveStrings.Localizable.errorDownload
    }
}
