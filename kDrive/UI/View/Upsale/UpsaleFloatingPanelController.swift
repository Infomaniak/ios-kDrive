/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import UIKit

class UpsaleFloatingPanelController: AdaptiveDriveFloatingPanelController {
    private let upsaleViewController: UpsaleViewController

    init(upsaleViewController: UpsaleViewController) {
        self.upsaleViewController = upsaleViewController

        super.init()

        set(contentViewController: upsaleViewController)
        track(scrollView: upsaleViewController.scrollView)

        surfaceView.grabberHandle.isHidden = true
        surfaceView.backgroundColor = .white
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Task { @MainActor in
            let height = max(upsaleViewController.scrollView.contentSize.height, 600.0)
            layout = UpsaleFloatingPanelLayout(height: height)
            invalidateLayout()
        }
    }
}

/// A dedicated layout that maintains a custom static height
class UpsaleFloatingPanelLayout: FloatingPanelLayout {
    var position: FloatingPanelPosition = .bottom

    var initialState: FloatingPanelState = .full

    var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] {
        return [
            .full: FloatingPanelLayoutAnchor(absoluteInset: height + 60, edge: .bottom, referenceGuide: .superview)
        ]
    }

    var height: CGFloat = 0

    init(height: CGFloat) {
        self.height = height
    }

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return 0.0
    }
}
