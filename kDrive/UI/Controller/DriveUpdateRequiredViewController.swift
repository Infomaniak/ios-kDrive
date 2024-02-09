/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import InfomaniakCoreUI
import kDriveResources
import SwiftUI
import UIKit
import VersionChecker
import kDriveCore

class DriveUpdateRequiredViewController: UIViewController {
    private let sharedStyle = TemplateSharedStyle(
        background: KDriveResourcesAsset.backgroundColor.swiftUIColor,
        titleTextStyle: .init(font: Font(TextStyle.header1.font), color: Color(TextStyle.header1.color)),
        descriptionTextStyle: .init(font: Font(TextStyle.body1.font), color: Color(TextStyle.body1.color)),
        buttonStyle: .init(
            background: .accentColor,
            textStyle: .init(font: Font(TextStyle.body1.font), color: .white),
            height: 60,
            radius: 16
        )
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingViewController = UIHostingController(rootView: UpdateRequiredView(
            image: KDriveResourcesAsset.updateRequired.swiftUIImage,
            sharedStyle: sharedStyle,
            handler: updateApp
        ))
        guard let hostingView = hostingViewController.view else { return }

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostingViewController)
        view.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingView.leftAnchor.constraint(equalTo: view.leftAnchor),
            hostingView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])

        hostingViewController.didMove(toParent: self)
    }

    private func updateApp() {
        let storeURL: URLConstants = Bundle.main.isRunningInTestFlight ? .testFlight : .appStore
        if UIApplication.shared.canOpenURL(storeURL.url) {
            UIApplication.shared.open(storeURL.url)
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    return DriveUpdateRequiredViewController()
}
