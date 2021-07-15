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

class FloatingPanelCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var buttonView: UIView!
    @IBOutlet weak var actionImage: UIImageView!
    @IBOutlet weak var actionLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var darkLayer: UIView!

    @IBOutlet weak var progressView: RPCircularProgress!
    private var observationToken: ObservationToken?

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.buttonView.backgroundColor = self.isHighlighted ? KDriveAsset.backgroundCardViewSelectedColor.color : KDriveAsset.backgroundColor.color
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.bringSubviewToFront(darkLayer)
        progressView.isHidden = true
        progressView.trackTintColor = KDriveAsset.secondaryTextColor.color.withAlphaComponent(0.2)
        progressView.progressTintColor = KDriveAsset.infomaniakColor.color
        progressView.thicknessRatio = 0.15
        progressView.indeterminateProgress = 0.75
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        observationToken?.cancel()
        observationToken = nil
        actionImage.isHidden = false
        progressView.isHidden = true
        progressView.updateProgress(0, animated: false)
    }

    func setProgress(_ progress: CGFloat? = -1) {
        if let downloadProgress = progress {
            actionImage.isHidden = true
            progressView.isHidden = false
            if downloadProgress < 0 {
                progressView.enableIndeterminate()
            } else {
                progressView.enableIndeterminate(false)
                progressView.updateProgress(downloadProgress)
            }
        } else {
            actionImage.isHidden = false
            progressView.isHidden = true
        }
    }

    func configureDownload(with file: File, action: FloatingPanelAction, progress: CGFloat?) {
        observationToken?.cancel()
        if progress == nil {
            actionImage.isHidden = false
            progressView.isHidden = true

            actionImage.image = action.image
            actionImage.tintColor = action.tintColor
        } else {
            loadingIndicator.stopAnimating()
            observationToken = DownloadQueue.instance.observeFileDownloadProgress(self, fileId: file.id) { _, progress in
                DispatchQueue.main.async { [weak self] in
                    guard self?.observationToken != nil else { return }
                    self?.setProgress(CGFloat(progress))
                    if progress >= 1 {
                        self?.configureDownload(with: file, action: action, progress: nil)
                    }
                }
            }
        }
    }
}
