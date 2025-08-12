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

import kDriveCore
import kDriveResources
import UIKit

class LockedFolderViewController: BaseInfoViewController {
    var destinationURL: URL?

    let openWebButton = IKLargeButton(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()

        centerImageView.image = KDriveResourcesAsset.lockExternal.image
        titleLabel.text = KDriveCoreStrings.Localizable.publicSharePasswordNeededTitle
        descriptionLabel.text = KDriveCoreStrings.Localizable.publicSharePasswordNotSupportedDescription

        setupOpenWebButton()
    }

    private func setupOpenWebButton() {
        openWebButton.setTitle(KDriveCoreStrings.Localizable.buttonOpenInBrowser, for: .normal)
        openWebButton.translatesAutoresizingMaskIntoConstraints = false
        openWebButton.addTarget(self, action: #selector(openWebBrowser), for: .touchUpInside)

        view.addSubview(openWebButton)
        view.bringSubviewToFront(openWebButton)

        let leadingConstraint = openWebButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor,
                                                                       constant: 25)
        leadingConstraint.priority = UILayoutPriority.defaultHigh
        let trailingConstraint = openWebButton.trailingAnchor.constraint(
            greaterThanOrEqualTo: view.trailingAnchor,
            constant: -25
        )
        trailingConstraint.priority = UILayoutPriority.defaultHigh
        let widthConstraint = openWebButton.widthAnchor.constraint(lessThanOrEqualToConstant: 360)

        NSLayoutConstraint.activate([
            openWebButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            leadingConstraint,
            trailingConstraint,
            openWebButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            openWebButton.heightAnchor.constraint(equalToConstant: 60),
            widthConstraint
        ])
    }

    @objc func openWebBrowser() {
        guard let destinationURL else {
            return
        }

        UIApplication.shared.open(destinationURL)
    }
}
