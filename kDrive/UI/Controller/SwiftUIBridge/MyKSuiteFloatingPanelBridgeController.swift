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

final class MyKSuiteFloatingPanelBridgeController: FloatingPanelController {
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

final class MyKSuiteFloatingPanelBridgeLayout: FloatingPanelLayout {
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

struct RedView: View {
    var body: some View {
        Color.red
            .edgesIgnoringSafeArea(.all)
    }
}

final class MyKSuiteBridgeViewController: UIViewController {
    let scrollView = UIScrollView()
    let swiftUIView =  MyKSuiteView(configuration: .kDrive) // RedView()
    lazy var hostingController = UIHostingController(rootView: ScrollView(){ swiftUIView })

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        addChild(hostingController)
        scrollView.addSubview(hostingController.view)
        hostingController.view.backgroundColor = .green

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
//            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
//        ])

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostingController.view.leadingAnchor.constraint(
                equalTo: scrollView.leadingAnchor,
                constant: UIConstants.Padding.standard
            ),
            hostingController.view.trailingAnchor.constraint(
                equalTo: scrollView.trailingAnchor,
                constant: -UIConstants.Padding.standard
            ),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hostingController.view.widthAnchor.constraint(
                equalTo: view.widthAnchor,
                constant: -(2 * UIConstants.Padding.standard)
            )
        ])

//        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: 600)
//        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)

        hostingController.didMove(toParent: self)
    }

    public static func instantiateInFloatingPanel(rootViewController: UIViewController) -> UIViewController {
        let upsaleViewController = MyKSuiteBridgeViewController()
        upsaleViewController.view.backgroundColor = .red
        return MyKSuiteUpsaleFloatingPanelController(upsaleViewController: upsaleViewController)
    }
}

// ___

final class MyKSuiteUpsaleFloatingPanelController: AdaptiveDriveFloatingPanelController {
    private let upsaleViewController: MyKSuiteBridgeViewController

    init(upsaleViewController: MyKSuiteBridgeViewController) {
        self.upsaleViewController = upsaleViewController

        super.init()

        set(contentViewController: upsaleViewController)
        trackAndObserve(scrollView: upsaleViewController.scrollView)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        guard let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }
        updateLayout(size: window.bounds.size)

        print("• SIZE\(window.bounds.size)")

        upsaleViewController.view.setNeedsLayout()
        upsaleViewController.scrollView.setNeedsLayout()

//        surfaceView.grabberHandle.isHidden = true
//        surfaceView.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
    }
}
