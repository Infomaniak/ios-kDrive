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

import AVKit
import kDriveCore
import Kingfisher
import UIKit

protocol DownloadProgressObserver {
    var progressView: UIProgressView! { get set }
    func setDownloadProgress(_ progress: Progress)
}

extension DownloadProgressObserver {
    func setDownloadProgress(_ progress: Progress) {
        progressView.isHidden = false
        progressView.observedProgress = progress
    }
}

class DownloadingPreviewCollectionViewCell: UICollectionViewCell, UIScrollViewDelegate, DownloadProgressObserver {
    @IBOutlet var previewZoomView: UIScrollView!
    @IBOutlet var previewImageView: UIImageView!
    @IBOutlet var progressView: UIProgressView!

    weak var previewDelegate: PreviewContentCellDelegate?
    private var file: File!
    var tapGestureRecognizer: UITapGestureRecognizer!
    private var tapToZoomRecognizer: UITapGestureRecognizer!
    var previewDownloadTask: Kingfisher.DownloadTask?

    override func awakeFromNib() {
        super.awakeFromNib()
        previewZoomView.delegate = self

        tapToZoomRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap))
        tapToZoomRecognizer.numberOfTapsRequired = 2
        previewZoomView.addGestureRecognizer(tapToZoomRecognizer)

        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOnCell))
        tapGestureRecognizer.require(toFail: tapToZoomRecognizer)
        addGestureRecognizer(tapGestureRecognizer)

        progressView.layer.cornerRadius = progressView.frame.height / 2
        progressView.backgroundColor = .white
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.image = nil
        previewDownloadTask?.cancel()
        progressView.isHidden = true
    }

    @objc func didTapOnCell() {
        previewDelegate?.setFullscreen(nil)
    }

    @objc private func didDoubleTap(_ sender: UITapGestureRecognizer) {
        if previewZoomView.zoomScale == previewZoomView.minimumZoomScale { // zoom in
            let point = sender.location(in: previewImageView)

            let scrollSize = previewZoomView.frame.size
            let size = CGSize(width: scrollSize.width / 3,
                              height: scrollSize.height / 3)
            let origin = CGPoint(x: point.x - size.width / 2,
                                 y: point.y - size.height / 2)
            previewZoomView.zoom(to: CGRect(origin: origin, size: size), animated: true)
        } else {
            previewZoomView.zoom(to: previewImageView.frame, animated: true)
        }
    }

    func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.height = previewImageView.frame.size.height / scale
        zoomRect.size.width = previewImageView.frame.size.width / scale
        let newCenter = previewZoomView.convert(center, from: previewImageView)
        zoomRect.origin.x = newCenter.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = newCenter.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return previewImageView
    }

    func progressiveLoadingForPublicShareFile(_ file: File, publicShareProxy: PublicShareProxy) {
        self.file = file
        file.getPublicShareThumbnail(publicShareId: publicShareProxy.shareLinkUid,
                                     publicDriveId: publicShareProxy.driveId,
                                     publicFileId: file.id,
                                     token: publicShareProxy.token) { thumbnail, _ in
            self.previewImageView.image = thumbnail
        }

        previewDownloadTask = file.getPublicSharePreview(publicShareId: publicShareProxy.shareLinkUid,
                                                         publicDriveId: publicShareProxy.driveId,
                                                         publicFileId: file.id,
                                                         token: publicShareProxy.token) { [weak previewImageView] preview in
            guard let previewImageView else {
                return
            }
            if let preview {
                previewImageView.image = preview
            }
        }
    }

    func progressiveLoadingForFile(_ file: File) {
        self.file = file
        file.getThumbnail { thumbnail, _ in
            self.previewImageView.image = thumbnail
        }

        previewDownloadTask = file.getPreview { [weak previewImageView] preview in
            guard let previewImageView else {
                return
            }
            if let preview {
                previewImageView.image = preview
            }
        }
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        previewDelegate?.setFullscreen(true)
    }
}

extension DownloadingPreviewCollectionViewCell: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Don't recognize a single tap until a double-tap fails.
        if gestureRecognizer == tapGestureRecognizer && otherGestureRecognizer == tapToZoomRecognizer {
            return true
        }
        return false
    }
}
