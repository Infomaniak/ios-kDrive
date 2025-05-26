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

import CocoaLumberjackSwift
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import InfomaniakLogin
import InfomaniakOnboarding
import kDriveCore
import kDriveResources
import Lottie
import UIKit

class OnboardingBottomViewController: UIViewController {
    private let titleText: String
    private let descriptionText: String

    init(title: String, description: String) {
        titleText = title
        descriptionText = description
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let onboardingView = OnboardingTextView(
            title: titleText,
            description: descriptionText
        )
        view.addSubview(onboardingView)

        onboardingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            onboardingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            onboardingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            onboardingView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            onboardingView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
}
