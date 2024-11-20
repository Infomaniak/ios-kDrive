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
        label.textColor = KDriveResourcesAsset.titleColor.color
        label.numberOfLines = 1
        label.textAlignment = .center
        label.text = KDriveStrings.Localizable.obtainkDriveAdTitle
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = KDriveResourcesAsset.primaryTextColor.color
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

    let dismissButton: IKLargeButton = {
        let button = IKLargeButton(frame: .zero)
        // TODO: Check secondary is white not grey
//        button.style = .secondaryButton
        button.backgroundColor = .lightGray
        // TODO: Dynamic switch to .buttonLogin
        button.setTitle(KDriveStrings.Localizable.buttonLater, for: .normal)
        button.addTarget(self, action: #selector(login), for: .touchUpInside)
        return button
    }()

    let scrollView = UIScrollView()

    let containerView = UIView()

    let bulletPointsView = UIView()

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        setupBody()
        layoutStackView()
    }

    /// Layout all the vertical elements of this view from code.
    private func setupBody() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        scrollView.addSubview(containerView)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])

        titleImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        bulletPointsView.translatesAutoresizingMaskIntoConstraints = false
        freeTrialButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(bulletPointsView)
        containerView.addSubview(titleImageView)
        containerView.addSubview(freeTrialButton)
        containerView.addSubview(dismissButton)

        let verticalConstraints = [
            titleImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.topAnchor.constraint(equalTo: titleImageView.bottomAnchor, constant: 24),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            bulletPointsView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
            freeTrialButton.topAnchor.constraint(equalTo: bulletPointsView.bottomAnchor, constant: 24),
            freeTrialButton.heightAnchor.constraint(equalToConstant: 45.0),
            dismissButton.topAnchor.constraint(equalTo: freeTrialButton.bottomAnchor, constant: 16),
            dismissButton.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            dismissButton.heightAnchor.constraint(equalToConstant: 45.0)
        ]

        let dismissButtonConstraintHigh = dismissButton.widthAnchor.constraint(
            equalTo: containerView.widthAnchor,
            multiplier: 1,
            constant: -24
        )
        dismissButtonConstraintHigh.priority = .defaultHigh

        let dismissButtonConstraintRequired = dismissButton.widthAnchor.constraint(lessThanOrEqualToConstant: 370)

        let freeTrialButtonConstraintHigh = freeTrialButton.widthAnchor.constraint(
            equalTo: containerView.widthAnchor,
            multiplier: 1,
            constant: -24
        )
        freeTrialButtonConstraintHigh.priority = .defaultHigh

        let freeTrialButtonConstraintRequired = freeTrialButton.widthAnchor.constraint(lessThanOrEqualToConstant: 370)

        let horizontalConstraints = [
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1, constant: -20),
            descriptionLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            descriptionLabel.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1, constant: -20),
            titleImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1),
            bulletPointsView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            bulletPointsView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1),
            freeTrialButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            freeTrialButtonConstraintHigh,
            freeTrialButtonConstraintRequired,
            dismissButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            dismissButtonConstraintHigh,
            dismissButtonConstraintRequired
        ]

        NSLayoutConstraint.activate(verticalConstraints)
        NSLayoutConstraint.activate(horizontalConstraints)
    }

    private func layoutStackView() {
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.spacing = 16
        mainStackView.alignment = .leading
        mainStackView.translatesAutoresizingMaskIntoConstraints = false

        mainStackView.addArrangedSubview(createRow(
            text: KDriveStrings.Localizable.obtainkDriveAdListing1
        ))
        mainStackView.addArrangedSubview(createRow(
            text: KDriveStrings.Localizable.obtainkDriveAdListing2
        ))
        mainStackView.addArrangedSubview(createRow(
            text: KDriveStrings.Localizable.obtainkDriveAdListing3
        ))

        bulletPointsView.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            mainStackView.heightAnchor.constraint(equalTo: bulletPointsView.heightAnchor),
            mainStackView.widthAnchor.constraint(equalTo: bulletPointsView.widthAnchor)
        ])
    }

    private func createRow(text: String) -> UIStackView {
        let imageView = UIImageView(image: KDriveResourcesAsset.select.image)
        imageView.contentMode = .scaleAspectFit

        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 20),
            imageView.widthAnchor.constraint(equalToConstant: 20)
        ])

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .left

        let rowStackView = UIStackView(arrangedSubviews: [UIView(), imageView, label])
        rowStackView.axis = .horizontal
        rowStackView.spacing = 16
        rowStackView.alignment = .top

        return rowStackView
    }

    @objc public func freeTrial() {
        dismiss(animated: true, completion: nil)
    }

    @objc public func login() {
        dismiss(animated: true, completion: nil)
    }
}
