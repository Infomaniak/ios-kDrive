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
class MyKSuiteDashboardViewBridgeController: UIViewController {
    let apiFetcher: DriveApiFetcher

    init(apiFetcher: DriveApiFetcher) {
        self.apiFetcher = apiFetcher
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let swiftUIView = MyKSuiteDashboardView(apiFetcher: apiFetcher)
        let hostingController = UIHostingController(rootView: swiftUIView)

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        hostingController.view.backgroundColor = .yellow
    }
}

@available(iOS 15, *)
class MyKSuiteDashboardViewBridge {
    static func hostingViewController(apiFetcher: DriveApiFetcher) -> UIViewController {
        let swiftUIView = MyKSuiteDashboardView(apiFetcher: apiFetcher)
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .yellow

        return hostingController
    }
}
