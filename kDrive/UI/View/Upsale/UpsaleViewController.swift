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
    var onLoginCompleted: (() -> Void)?
    var onFreeTrialCompleted: (() -> Void)?

    let titleImageView = UIImageView()

    let titleLabel: UILabel = {
        let label = IKLabel()
        label.style = .header2
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = KDriveStrings.Localizable.obtainkDriveAdTitle
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = IKLabel()
        label.style = .subtitle1
        label.textColor = KDriveResourcesAsset.primaryTextColor.color
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = KDriveStrings.Localizable.obtainkDriveAdDescription
        return label
    }()

    let freeTrialButton = IKLargeButton(frame: .zero)

    let dismissButton = IKLargeButton(frame: .zero)

    let scrollView = UIScrollView()

    let containerView = UIView()

    let bulletPointsView = UIView()

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        configureButtons()
        configureHeader()
        setupBody()
        layoutStackView()
    }

    func configureHeader() {
        titleImageView.contentMode = .scaleAspectFit
        titleImageView.image = KDriveResourcesAsset.upsaleHeader.image
    }

    func configureButtons() {
        freeTrialButton.style = .primaryButton
        freeTrialButton.setTitle(KDriveStrings.Localizable.obtainkDriveAdFreeTrialButton, for: .normal)
        freeTrialButton.addTarget(self, action: #selector(freeTrial), for: .touchUpInside)

        dismissButton.style = .secondaryButton
        dismissButton.setTitle(KDriveStrings.Localizable.obtainkDriveAdAlreadyGotAccount, for: .normal)
        dismissButton.addTarget(self, action: #selector(login), for: .touchUpInside)
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
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: UIConstants.Padding.standard),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -UIConstants.Padding.standard),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -(2 * UIConstants.Padding.standard))
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
            titleImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.topAnchor.constraint(equalTo: titleImageView.bottomAnchor, constant: UIConstants.Padding.standard),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: UIConstants.Padding.standard),
            bulletPointsView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: UIConstants.Padding.standard),
            freeTrialButton.topAnchor.constraint(equalTo: bulletPointsView.bottomAnchor, constant: UIConstants.Padding.standard),
            freeTrialButton.heightAnchor.constraint(equalToConstant: UIConstants.Button.largeHeight),
            dismissButton.topAnchor.constraint(equalTo: freeTrialButton.bottomAnchor, constant: UIConstants.Padding.medium),
            dismissButton.bottomAnchor.constraint(
                equalTo: containerView.safeAreaLayoutGuide.bottomAnchor,
                constant: -UIConstants.Padding.small
            ),
            dismissButton.heightAnchor.constraint(equalToConstant: UIConstants.Button.largeHeight)
        ]

        let dismissButtonConstraintHigh = dismissButton.widthAnchor.constraint(
            equalTo: containerView.widthAnchor,
            multiplier: 1
        )
        dismissButtonConstraintHigh.priority = .defaultHigh

        let dismissButtonConstraintRequired = dismissButton.widthAnchor.constraint(lessThanOrEqualToConstant: 370)

        let freeTrialButtonConstraintHigh = freeTrialButton.widthAnchor.constraint(
            equalTo: containerView.widthAnchor,
            multiplier: 1
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
        mainStackView.spacing = UIConstants.Padding.medium
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

        let label = IKLabel()
        label.style = .subtitle1
        label.text = text
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .left

        let rowStackView = UIStackView(arrangedSubviews: [imageView, label])
        rowStackView.axis = .horizontal
        rowStackView.spacing = UIConstants.Padding.medium
        rowStackView.alignment = .top

        return rowStackView
    }

    @objc public func freeTrial() {
        dismiss(animated: true, completion: nil)
        onFreeTrialCompleted?()
    }

    @objc public func login() {
        dismiss(animated: true, completion: nil)
        onLoginCompleted?()
    }
}
