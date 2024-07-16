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

class ImagePreviewCollectionViewCell: PreviewCollectionViewCell, UIScrollViewDelegate {
    @IBOutlet var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet var imageWidthConstraint: NSLayoutConstraint!
    @IBOutlet var zoomScrollView: UIScrollView!
    @IBOutlet var imagePreview: UIImageView!
    private var tapToZoomRecognizer: UITapGestureRecognizer!

    override func awakeFromNib() {
        super.awakeFromNib()
        zoomScrollView.delegate = self
        tapToZoomRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap))
        tapToZoomRecognizer.numberOfTapsRequired = 2
        zoomScrollView.addGestureRecognizer(tapToZoomRecognizer)
    }

    @objc private func didDoubleTap(_ sender: UITapGestureRecognizer) {
        if zoomScrollView.zoomScale == zoomScrollView.minimumZoomScale { // zoom in
            let point = sender.location(in: imagePreview)

            let scrollSize = imagePreview.frame.size
            let size = CGSize(width: scrollSize.width / 3,
                              height: scrollSize.height / 3)
            let origin = CGPoint(x: point.x - size.width / 2,
                                 y: point.y - size.height / 2)
            zoomScrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
        } else {
            zoomScrollView.zoom(to: imagePreview.frame, animated: true)
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imagePreview
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        previewDelegate?.setFullscreen(true)
    }
}

extension ImagePreviewCollectionViewCell: UIGestureRecognizerDelegate {
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
