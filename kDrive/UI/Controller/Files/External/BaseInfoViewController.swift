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

class BaseInfoViewController: UIViewController {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = KDriveResourcesAsset.primaryTextColor.color
        label.numberOfLines = 1
        label.textAlignment = .center
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = KDriveResourcesAsset.secondaryTextColor.color
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    let centerImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let closeButton: IKButton = {
        let button = IKButton()
        button.setImage(UIImage(named: "close"), for: .normal)
        return button
    }()

    let containerView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        setupCloseButton()
        setupBody()
    }

    private func setupCloseButton() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        closeButton.addTarget(self, action: #selector(closeButtonPressed), for: .touchUpInside)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            closeButton.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 25)
        ])
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

        let views = ["titleLabel": titleLabel,
                     "descriptionLabel": descriptionLabel,
                     "centerImageView": centerImageView]

        let verticalConstraints = NSLayoutConstraint
            .constraints(withVisualFormat: "V:|[centerImageView]-[titleLabel]-[descriptionLabel]|",
                         metrics: nil,
                         views: views)

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
