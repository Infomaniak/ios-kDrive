/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import MyKSuite
import SwiftUI
import UIKit

@available(iOS 15, *)
class MyKSuiteFloatingPanelBridgeController: FloatingPanelController {
    init() {
        super.init(delegate: nil)
        let appearance = SurfaceAppearance()
        appearance.cornerRadius = UIConstants.FloatingPanel.cornerRadius
        appearance.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        surfaceView.appearance = appearance
        surfaceView.grabberHandlePadding = 16
        surfaceView.grabberHandleSize = CGSize(width: 45, height: 5)
        surfaceView.grabberHandle.barColor = KDriveResourcesAsset.iconColor.color.withAlphaComponent(0.4)
        surfaceView.contentPadding = UIEdgeInsets(top: 24, left: 0, bottom: 0, right: 0)
        backdropView.dismissalTapGestureRecognizer.isEnabled = true
        layout = MyKSuiteFloatingPanelBridgeLayout()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(iOS 15, *)
class MyKSuiteFloatingPanelBridgeLayout: FloatingPanelLayout {
    var position: FloatingPanelPosition = .bottom
    var initialState: FloatingPanelState = .tip
    var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring]
    private var backdropAlpha: CGFloat

    init(
        initialState: FloatingPanelState = .full,
        hideTip: Bool = false,
        safeAreaInset: CGFloat = 0,
        backdropAlpha: CGFloat = 0
    ) {
        self.initialState = initialState
        self.backdropAlpha = backdropAlpha
        let extendedAnchor = FloatingPanelLayoutAnchor(
            absoluteInset: 620.0 + safeAreaInset,
            edge: .bottom,
            referenceGuide: .superview
        )
        anchors = [
            .full: extendedAnchor,
            .half: extendedAnchor,
            .tip: FloatingPanelLayoutAnchor(absoluteInset: 86.0 + safeAreaInset, edge: .bottom, referenceGuide: .superview)
        ]
    }

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return backdropAlpha
    }
}

@available(iOS 15, *)
class MyKSuiteBridgeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let swiftUIView = MyKSuiteView(configuration: .kDrive)
        let hostingController = UIHostingController(rootView: swiftUIView)

        addChild(hostingController)
        let sourceBounds = view.bounds
        let adjustedFrame = CGRect(x: 0,
                                   y: -140,
                                   width: sourceBounds.width,
                                   height: sourceBounds.height)
        hostingController.view.frame = adjustedFrame
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        // hostingController.view.backgroundColor = .yellow
    }
}
