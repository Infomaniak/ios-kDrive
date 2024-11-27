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

import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import UIKit

class BaseInfoViewController: UIViewController {
    let titleLabel: IKLabel = {
        let label = IKLabel()
        label.style = .header1
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    let descriptionLabel: IKLabel = {
        let label = IKLabel()
        label.style = .body2
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    let centerImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let containerView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        setupCloseButton()
        setupBody()
    }

    private func setupCloseButton() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
        closeButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
        navigationItem.leftBarButtonItem = closeButton
    }

    private func setupBody() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        centerImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(centerImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)

        let verticalConstraints = [
            centerImageView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor),
            titleLabel.topAnchor.constraint(equalTo: centerImageView.bottomAnchor, constant: 8),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor)
        ]

        let horizontalConstraints = [
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1, constant: -20),
            descriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            descriptionLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1, constant: -20),
            centerImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1)
        ]

        NSLayoutConstraint.activate(verticalConstraints)
        NSLayoutConstraint.activate(horizontalConstraints)
    }

    @objc open func closeButtonPressed() {
        dismiss(animated: true)
    }
}
