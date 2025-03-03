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
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class FloatingPanelQuickActionCollectionViewCell: UICollectionViewCell {
    @IBOutlet var buttonView: UIView!
    @IBOutlet var actionImage: UIImageView!
    @IBOutlet var actionLabel: UILabel!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet var darkLayer: UIView!

    @IBOutlet var progressView: RPCircularProgress!
    private var observationToken: ObservationToken?

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.buttonView.backgroundColor = self.isHighlighted ? KDriveResourcesAsset.backgroundCardViewSelectedColor
                    .color : KDriveResourcesAsset.backgroundColor.color
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.bringSubviewToFront(darkLayer)
        progressView.isHidden = true
        progressView.setInfomaniakStyle()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        observationToken?.cancel()
        observationToken = nil
        actionImage.isHidden = false
        progressView.isHidden = true
        progressView.updateProgress(0, animated: false)
    }

    #if !ISEXTENSION
    func configure(with action: FloatingPanelAction, file: File) {
        guard !file.isInvalidated else { return }
        configure(
            name: action.name,
            icon: action.image,
            tintColor: action.tintColor,
            isEnabled: action.isEnabled,
            isLoading: action.isLoading
        )
        // Configuration
        if action == .shareLink {
            if file.isDropbox {
                actionLabel.text = KDriveResourcesStrings.Localizable.buttonShareDropboxLink
            } else if file.hasSharelink {
                actionLabel.text = action.reverseName
            }
        } else if action == .sendCopy {
            configureDownload(with: file, action: action, progress: action.isLoading ? -1 : nil)
        }
    }
    #endif

    func configure(name: String, icon: UIImage, tintColor: UIColor, isEnabled: Bool, isLoading: Bool) {
        actionImage.isHidden = isLoading
        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
        actionImage.image = icon
        actionImage.tintColor = tintColor
        actionLabel.text = name
        darkLayer.isHidden = isEnabled
        // Accessibility
        accessibilityLabel = name
        accessibilityTraits = isEnabled ? .button : .notEnabled
        isAccessibilityElement = true
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

    #if !ISEXTENSION
    func configureDownload(with file: File, action: FloatingPanelAction, progress: CGFloat?) {
        @LazyInjectService var downloadQueue: DownloadQueueable
        observationToken?.cancel()
        if progress == nil {
            actionImage.isHidden = false
            progressView.isHidden = true

            actionImage.image = action.image
            actionImage.tintColor = action.tintColor
        } else {
            loadingIndicator.stopAnimating()
            observationToken = downloadQueue.observeFileDownloadProgress(self, fileId: file.id) { _, progress in
                Task { @MainActor [weak self] in
                    guard self?.observationToken != nil else { return }
                    self?.setProgress(progress)
                    if progress >= 1 {
                        self?.configureDownload(with: file, action: action, progress: nil)
                    }
                }
            }
        }
    }
    #endif
}
