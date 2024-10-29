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

import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import UIKit

public class UpsaleViewController: UIViewController {

    let titleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = KDriveResourcesAsset.upsaleHeader.image
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        // Some factorisation can be done in kDrive
        label.font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 22), weight: .bold)
        label.textColor = KDriveResourcesAsset.primaryTextColor.color
        label.numberOfLines = 1
        label.textAlignment = .center
        label.text = KDriveStrings.Localizable.obtainkDriveAdTitle
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = KDriveResourcesAsset.secondaryTextColor.color
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = KDriveStrings.Localizable.obtainkDriveAdDescription
        return label
    }()

    let freeTrialButton: IKLargeButton = {
        let button = IKLargeButton(frame: .zero)
        button.setTitle(KDriveStrings.Localizable.obtainkDriveAdFreeTrialButton, for: .normal)
        button.addTarget(self, action: #selector(freeTrial), for: .touchUpInside)
        return button
    }()

    let loginButton: IKLargeButton = {
        let button = IKLargeButton(frame: .zero)
        button.setTitle(KDriveStrings.Localizable.buttonLogin, for: .normal)
        button.addTarget(self, action: #selector(login), for: .touchUpInside)
        return button
    }()

    let containerView = UIView()

    let bulletPointsView = UIView()

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        setupBody()
        setupBulletPoints()
    }

    /// Layout all the vertical elements of this view from code.
    private func setupBody() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor),
            containerView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])

        titleImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        bulletPointsView.translatesAutoresizingMaskIntoConstraints = false
        freeTrialButton.translatesAutoresizingMaskIntoConstraints = false
        loginButton.translatesAutoresizingMaskIntoConstraints = false

        // TODO: remove
        containerView.backgroundColor = .purple
        titleLabel.backgroundColor = .blue
        descriptionLabel.backgroundColor = .green
        bulletPointsView.backgroundColor = .yellow

        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(bulletPointsView)
        containerView.addSubview(titleImageView)
        containerView.addSubview(freeTrialButton)
        containerView.addSubview(loginButton)

        let views = ["titleLabel": titleLabel,
                     "descriptionLabel": descriptionLabel,
                     "titleImageView": titleImageView,
                     "bulletPointsView": bulletPointsView,
                     "freeTrialButton": freeTrialButton,
                     "loginButton": loginButton]

        let verticalConstraints = NSLayoutConstraint
            .constraints(
                withVisualFormat: "V:|-24-[titleImageView]-24-[titleLabel]-24-[descriptionLabel]-24-[bulletPointsView(>=10)]->=8-[freeTrialButton(45)]-16-[loginButton(45)]-|",
                metrics: nil,
                views: views
            )

        let horizontalConstraints = [
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1, constant: -20),
            descriptionLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            descriptionLabel.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1, constant: -20),
            titleImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1),
            bulletPointsView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            bulletPointsView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1, constant: -8),
            freeTrialButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            freeTrialButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1, constant: -8),
            loginButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loginButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1, constant: -8)
        ]

        NSLayoutConstraint.activate(verticalConstraints)
        NSLayoutConstraint.activate(horizontalConstraints)
    }

    /// Dynamically set auto-layout constraints for the bullet points
    private func setupBulletPoints() {
        let adListings = [KDriveStrings.Localizable.obtainkDriveAdListing1,
                          KDriveStrings.Localizable.obtainkDriveAdListing2,
                          KDriveStrings.Localizable.obtainkDriveAdListing3]
        var verticalViews = [String: UIView]()
        var verticalContraintString = "V:|"
        for (index, ad) in adListings.enumerated() {
            let container = UIView()
            let containerViewId = "view\(index)"
            container.translatesAutoresizingMaskIntoConstraints = false
            bulletPointsView.addSubview(container)

            verticalViews[containerViewId] = container
            verticalContraintString += "[\(containerViewId)]-12-"

            layoutBulletPointView(
                txt: ad,
                container: container
            )

            let horizontalConstraints = [
                container.centerXAnchor.constraint(equalTo: bulletPointsView.centerXAnchor),
                container.widthAnchor.constraint(equalTo: bulletPointsView.widthAnchor)
            ]
            NSLayoutConstraint.activate(horizontalConstraints)
        }
        verticalContraintString += "|"

        let verticalConstraints = NSLayoutConstraint
            .constraints(withVisualFormat: verticalContraintString,
                         metrics: nil,
                         views: verticalViews)

        NSLayoutConstraint.activate(verticalConstraints)
    }

    private func layoutBulletPointView(txt: String, container: UIView) {
        container.backgroundColor = .orange

        let label = UILabel()
        let bullet = UIImageView()

        label.textAlignment = .left
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.text = txt

        bullet.image = KDriveResourcesAsset.select.image

        label.translatesAutoresizingMaskIntoConstraints = false
        bullet.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(bullet)

        // TODO: remove
        label.backgroundColor = .purple

        let verticalConstraints = [
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 1),
            label.rightAnchor.constraint(equalTo: container.rightAnchor),
            bullet.topAnchor.constraint(equalTo: container.topAnchor),
            bullet.heightAnchor.constraint(equalTo: bullet.widthAnchor)
        ]

        let views = ["label": label, "bullet": bullet]

        let horizontalConstraints = NSLayoutConstraint
            .constraints(withVisualFormat: "H:|-[bullet]-[label]-8-|",
                         metrics: nil,
                         views: views)

        NSLayoutConstraint.activate(verticalConstraints)
        NSLayoutConstraint.activate(horizontalConstraints)
    }

    @objc public func freeTrial() {
        dismiss(animated: true, completion: nil)
    }

    @objc public func login() {
        dismiss(animated: true, completion: nil)
    }
}
