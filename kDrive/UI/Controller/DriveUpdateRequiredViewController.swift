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

import InfomaniakCoreCommonUI
import kDriveCore
import kDriveResources
import SwiftUI
import UIKit
import VersionChecker

class DriveUpdateRequiredViewController: UIViewController {
    var dismissHandler: (() -> Void)?

    private let sharedStyle: TemplateSharedStyle = {
        let largeButtonStyle = IKLargeButton.Style.primaryButton
        return TemplateSharedStyle(
            background: KDriveResourcesAsset.backgroundColor.swiftUIColor,
            titleTextStyle: .init(font: Font(TextStyle.header2.font), color: Color(TextStyle.header2.color)),
            descriptionTextStyle: .init(font: Font(TextStyle.body1.font), color: Color(TextStyle.body1.color)),
            buttonStyle: .init(
                background: Color(largeButtonStyle.backgroundColor),
                textStyle: .init(font: Font(largeButtonStyle.titleFont), color: Color(largeButtonStyle.titleColor)),
                height: UIConstants.Button.largeHeight,
                radius: UIConstants.Button.cornerRadius
            )
        )
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingViewController = UIHostingController(rootView: UpdateRequiredView(
            image: KDriveResourcesAsset.updateRequired.swiftUIImage,
            sharedStyle: sharedStyle,
            updateHandler: updateApp,
            dismissHandler: dismissHandler
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func updateApp() {
        let storeURL: URLConstants = Bundle.main.isRunningInTestFlight ? .testFlight : .appStore
        UIConstants.openUrl(storeURL.url, from: self)
    }
}

@available(iOS 17.0, *)
#Preview {
    return DriveUpdateRequiredViewController()
}
