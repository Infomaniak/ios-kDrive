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

class NoPreviewCollectionViewCell: UICollectionViewCell, DownloadProgressObserver {
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var offlineView: UIView!
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var openButton: IKLargeIconButton!
    var tapGestureRecognizer: UITapGestureRecognizer!
    weak var previewDelegate: PreviewContentCellDelegate?

    private var observationToken: ObservationToken?
    @LazyInjectService var downloadQueue: DownloadQueueable

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

    func configureWith(file: File, errorReason: String) {
        titleLabel.text = file.name
        iconImageView.image = file.icon
        iconImageView.tintColor = file.tintColor
        subtitleLabel.text = errorReason
        offlineView.isHidden = true
        openButton.isHidden = true
        progressView.isHidden = true
    }

    func configureWith(file: File, isOffline: Bool = false) {
        titleLabel.text = file.name

        iconImageView.image = file.icon
        iconImageView.tintColor = file.tintColor
        subtitleLabel.text = KDriveResourcesStrings.Localizable.previewNoPreview
        offlineView.isHidden = !isOffline
        // Hide "open with" button if file will be downloaded and displayed
        openButton.isHidden = ConvertedType.downloadableTypes.contains(file.convertedType)

        if isOffline {
            subtitleLabel.text = KDriveResourcesStrings.Localizable.previewLoadError
            openButton.isHidden = !file.isMostRecentDownloaded
        }
    }

    func setDownloadProgress(_ progress: Progress) {
        progressView.isHidden = false
        progressView.observedProgress = progress
        subtitleLabel.text = KDriveResourcesStrings.Localizable.previewDownloadIndication
    }

    func observeProgress(_ showProgress: Bool, file: File) {
        observationToken?.cancel()
        progressView.isHidden = !showProgress
        progressView.progress = 0
        if showProgress {
            observationToken = downloadQueue.observeFileDownloadProgress(self, fileId: file.id) { _, progress in
                Task { @MainActor [weak self] in
                    self?.progressView.progress = Float(progress)
                }
            }
        }
    }

    func errorDownloading() {
        progressView.isHidden = true
        subtitleLabel.text = KDriveResourcesStrings.Localizable.errorDownload
    }

    @IBAction func openFileWith(_ sender: UIButton) {
        previewDelegate?.openWith(from: sender)
    }
}
