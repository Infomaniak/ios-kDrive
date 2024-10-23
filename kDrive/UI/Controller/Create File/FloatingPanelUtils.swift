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

import FloatingPanel
import kDriveCore
import kDriveResources
import UIKit

class DriveFloatingPanelController: FloatingPanelController {
    init() {
        super.init(delegate: nil)
        let appearance = SurfaceAppearance()
        appearance.cornerRadius = UIConstants.floatingPanelCornerRadius
        appearance.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        surfaceView.appearance = appearance
        surfaceView.grabberHandlePadding = 16
        surfaceView.grabberHandleSize = CGSize(width: 45, height: 5)
        surfaceView.grabberHandle.barColor = KDriveResourcesAsset.iconColor.color.withAlphaComponent(0.4)
        surfaceView.contentPadding = UIEdgeInsets(top: 24, left: 0, bottom: 0, right: 0)
        backdropView.dismissalTapGestureRecognizer.isEnabled = true
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AdaptiveDriveFloatingPanelController: DriveFloatingPanelController {
    private var contentSizeObservation: NSKeyValueObservation?

    deinit {
        contentSizeObservation?.invalidate()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateLayout(size: size)
    }

    func updateLayout(size: CGSize) {
        guard let trackingScrollView else { return }
        layout = PlusButtonFloatingPanelLayout(height: min(
            trackingScrollView.contentSize.height + surfaceView.contentPadding.top,
            size.height - 48
        ))
        invalidateLayout()
    }

    func trackAndObserve(scrollView: UIScrollView) {
        contentSizeObservation?.invalidate()
        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .old]) { [weak self] _, observedChanges in
            // Do not update layout if the new value is the same as the old one (to fix a bug with collectionView)
            guard observedChanges.newValue != observedChanges.oldValue,
                  let window = self?.view.window else { return }
            self?.updateLayout(size: window.bounds.size)
        }
        track(scrollView: scrollView)
    }
}
