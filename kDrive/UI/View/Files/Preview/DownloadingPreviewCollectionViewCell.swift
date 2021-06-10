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
import Kingfisher
import AVKit

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

    @IBOutlet weak var previewZoomView: UIScrollView!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!

    private var file: File!
    private var tapToZoomRecognizer: UITapGestureRecognizer!
    var previewDownloadTask: Kingfisher.DownloadTask?
    weak var parentViewController: UIViewController?

    override func awakeFromNib() {
        super.awakeFromNib()
        previewZoomView.delegate = self
        tapToZoomRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap))
        tapToZoomRecognizer.numberOfTapsRequired = 2
        previewZoomView.addGestureRecognizer(tapToZoomRecognizer)

        progressView.layer.cornerRadius = progressView.frame.height / 2
        progressView.backgroundColor = .white
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.image = nil
        previewDownloadTask?.cancel()
        progressView.isHidden = true
    }

    @objc private func didDoubleTap(_ sender: UITapGestureRecognizer) {
        let scale = min(previewZoomView.zoomScale * 2, previewZoomView.maximumZoomScale)

        if scale != previewZoomView.zoomScale { // zoom in
            let point = sender.location(in: previewImageView)

            let scrollSize = previewZoomView.frame.size
            let size = CGSize(width: scrollSize.width / previewZoomView.maximumZoomScale,
                height: scrollSize.height / previewZoomView.maximumZoomScale)
            let origin = CGPoint(x: point.x - size.width / 2,
                y: point.y - size.height / 2)
            previewZoomView.zoom(to: CGRect(origin: origin, size: size), animated: true)
        } else {
            previewZoomView.zoom(to: zoomRectForScale(scale: previewZoomView.maximumZoomScale, center: sender.location(in: previewImageView)), animated: true)
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

    func progressiveLoadingForFile(_ file: File) {
        self.file = file
        file.getThumbnail { thumbnail, _ in
            self.previewImageView.image = thumbnail
        }

        previewDownloadTask = file.getPreview { [weak previewImageView] preview in
            guard let previewImageView = previewImageView else {
                return
            }
            if let preview = preview {
                previewImageView.image = preview
            }
        }
    }

}
