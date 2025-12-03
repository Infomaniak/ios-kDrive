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

import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import MaterialOutlinedTextField
import UIKit

public class PasswordViewController: UIViewController, UITextFieldDelegate {
    @InjectService var publicShareApiFetcher: PublicShareApiFetcher
    @InjectService var router: AppNavigable

    let imageView = UIImageView()

    let titleLabel: UILabel = {
        let label = IKLabel()
        label.style = .header2
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = KDriveStrings.Localizable.publicSharePasswordNeededTitle
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = IKLabel()
        label.style = .subtitle1
        label.textColor = KDriveResourcesAsset.primaryTextColor.color
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = KDriveStrings.Localizable.publicSharePasswordNeededDescription
        return label
    }()

    lazy var validatePasswordButton: IKLargeButton = {
        let button = IKLargeButton(frame: .zero)
        button.setTitle(KDriveCoreStrings.Localizable.buttonValid, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(sendPassword), for: .touchUpInside)
        return button
    }()

    var passwordTextField = MaterialOutlinedTextField()
    private var showPassword = false

    let publicShareLink: PublicShareLink

    init(publicShareLink: PublicShareLink) {
        self.publicShareLink = publicShareLink
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        navigationItem.leftBarButtonItem = FileListBarButton(type: .cancel, target: self, action: #selector(close))

        setupBody()
        configurePasswordTextField()
        setupFooter()
    }

    private func configurePasswordTextField() {
        passwordTextField.delegate = self
        passwordTextField.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        passwordTextField.setInfomaniakColors()

        passwordTextField.setHint(KDriveResourcesStrings.Localizable.allPasswordHint)
        passwordTextField.isSecureTextEntry = !showPassword
        passwordTextField.keyboardType = .default
        passwordTextField.autocorrectionType = .no
        passwordTextField.autocapitalizationType = .none

        let overlayButton = UIButton(type: .custom)
        let viewImage = KDriveResourcesAsset.view.image
        overlayButton.setImage(viewImage, for: .normal)
        overlayButton.tintColor = KDriveResourcesAsset.iconColor.color
        overlayButton.addTarget(self, action: #selector(displayPassword), for: .touchUpInside)
        overlayButton.sizeToFit()
        overlayButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonTogglePassword

        let rightView = UIView(
            frame: CGRect(x: 0, y: 0, width: overlayButton.frame.width + 10, height: overlayButton.frame.height)
        )
        rightView.addSubview(overlayButton)
        passwordTextField.rightView = rightView
        passwordTextField.rightViewMode = .always
    }

    private func setupBody() {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        imageView.contentMode = .scaleAspectFit
        imageView.image = KDriveResourcesAsset.lockExternal.image

        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(imageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(passwordTextField)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UIConstants.Padding.standard),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -UIConstants.Padding.standard),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.5),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: UIConstants.Padding.standard),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: UIConstants.Padding.standard),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            passwordTextField.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor,
                                                   constant: UIConstants.Padding.standard),
            passwordTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            passwordTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            passwordTextField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    private func setupFooter() {
        view.addSubview(validatePasswordButton)
        view.bringSubviewToFront(validatePasswordButton)

        let leadingConstraint = validatePasswordButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor,
                                                                                constant: 16)
        leadingConstraint.priority = .defaultHigh
        let trailingConstraint = validatePasswordButton.trailingAnchor.constraint(
            greaterThanOrEqualTo: view.trailingAnchor,
            constant: -16
        )
        trailingConstraint.priority = .defaultHigh
        let widthConstraint = validatePasswordButton.widthAnchor.constraint(lessThanOrEqualToConstant: 360)

        NSLayoutConstraint.activate([
            validatePasswordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            leadingConstraint,
            trailingConstraint,
            validatePasswordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            validatePasswordButton.heightAnchor.constraint(equalToConstant: 60),
            widthConstraint
        ])
    }

    @objc private func displayPassword() {
        showPassword.toggle()
        passwordTextField.isSecureTextEntry = !showPassword
    }

    @objc private func sendPassword() {
        guard let password = passwordTextField.text, !password.isEmpty else {
            return
        }

        Task {
            do {
                let token = try await publicShareApiFetcher.getToken(driveId: publicShareLink.driveId,
                                                                     shareLinkUid: publicShareLink.shareLinkUid,
                                                                     password: password)
                await router.navigate(to: .publicShare(publicShareLink: publicShareLink, token: token))
            } catch {
                @InjectService var notificationHelper: NotificationsHelpable
                notificationHelper.sendWrongPasswordNotification()
            }
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
