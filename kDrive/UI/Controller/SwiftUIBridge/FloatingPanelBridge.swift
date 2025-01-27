//
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
import SwiftUI
import UIKit

@available(iOS 15, *)
class FloatingPanelBridgeController: FloatingPanelController {
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
        layout = FloatingPanelBridgeLayout()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(iOS 15, *)
class FloatingPanelBridgeLayout: FloatingPanelLayout {
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
            absoluteInset: 320.0 + safeAreaInset,
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
class BridgeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let helloWorldSwiftUIView = HelloWorldView()
        let hostingController = UIHostingController(rootView: helloWorldSwiftUIView)

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}

@available(iOS 15, *)
struct HelloWorldView: View {
    var body: some View {
        ZStack {
            Color.yellow
                .ignoresSafeArea()
            Text("Hello, World!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

// struct HelloWorldView_Previews: PreviewProvider {
//    static var previews: some View {
//        HelloWorldView()
//    }
// }
