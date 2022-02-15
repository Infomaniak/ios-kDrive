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
import kDriveResources
import UIKit

class NoPreviewCollectionViewCell: UICollectionViewCell, DownloadProgressObserver {
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var offlineView: UIStackView!
    @IBOutlet weak var progressView: UIProgressView!
    var tapGestureRecognizer: UITapGestureRecognizer!
    weak var previewDelegate: PreviewContentCellDelegate?
    weak var fileActonsFloatingPanel: FileActionsFloatingPanelViewController?

    var file: File!

    override func awakeFromNib() {
        super.awakeFromNib()
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOnCell))
        addGestureRecognizer(tapGestureRecognizer)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        progressView.progress = 0
        progressView.observedProgress = nil
        progressView.isHidden = true
    }

    @objc func didTapOnCell() {
        previewDelegate?.setFullscreen(nil)
    }

    func configureWith(file: File, isOffline: Bool = false) {
        self.file = file
        titleLabel.text = file.name
        if isOffline {
            iconImageView.image = KDriveResourcesAsset.fileDefault.image
            subtitleLabel.text = KDriveResourcesStrings.Localizable.previewLoadError
            offlineView.isHidden = false
        } else {
            iconImageView.image = file.icon
            iconImageView.tintColor = file.tintColor
            subtitleLabel.text = KDriveResourcesStrings.Localizable.previewNoPreview
            offlineView.isHidden = true
        }
    }

    func setDownloadProgress(_ progress: Progress) {
        progressView.isHidden = false
        progressView.observedProgress = progress
        subtitleLabel.text = KDriveResourcesStrings.Localizable.previewDownloadIndication
    }

    func errorDownloading() {
        progressView.isHidden = true
        subtitleLabel.text = KDriveResourcesStrings.Localizable.errorDownload
    }

    @IBAction func openFileWith(_ sender: UIButton) {
        previewDelegate?.openWith(from: sender.frame)
    }
}
