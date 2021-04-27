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

class ImagePreviewCollectionViewCell: PreviewCollectionViewCell, UIScrollViewDelegate {

    @IBOutlet weak var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var zoomScrollView: UIScrollView!
    @IBOutlet weak var imagePreview: UIImageView!
    private var tapToZoomRecognizer: UITapGestureRecognizer!

    override func awakeFromNib() {
        super.awakeFromNib()
        zoomScrollView.delegate = self
        tapToZoomRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap))
        tapToZoomRecognizer.numberOfTapsRequired = 2
        zoomScrollView.addGestureRecognizer(tapToZoomRecognizer)
    }

    @objc private func didDoubleTap(_ sender: UITapGestureRecognizer) {
        let scale = min(zoomScrollView.zoomScale * 2, zoomScrollView.maximumZoomScale)

        if scale != zoomScrollView.zoomScale { // zoom in
            let point = sender.location(in: imagePreview)

            let scrollSize = imagePreview.frame.size
            let size = CGSize(width: scrollSize.width / zoomScrollView.maximumZoomScale,
                height: scrollSize.height / zoomScrollView.maximumZoomScale)
            let origin = CGPoint(x: point.x - size.width / 2,
                y: point.y - size.height / 2)
            zoomScrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
        } else {
            zoomScrollView.zoom(to: zoomRectForScale(scale: zoomScrollView.maximumZoomScale, center: sender.location(in: imagePreview)), animated: true)
        }
    }

    func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.height = imagePreview.frame.size.height / scale
        zoomRect.size.width = imagePreview.frame.size.width / scale
        let newCenter = zoomScrollView.convert(center, from: imagePreview)
        zoomRect.origin.x = newCenter.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = newCenter.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imagePreview
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        previewDelegate?.setFullscreen(scrollView.zoomScale != 1.0)
    }

}
