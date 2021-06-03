/*
Infomaniak kDrive - iOS App
Copyright (C) 2021 Infomaniak Network SA

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

import UIKit
import kDriveCore

/**
 Alert view controller superclass.
 Do **not** use this class directly, instead subclass it or use one of the existing subclasses:
 `AlertTextViewController`, `AlertFieldViewController`, `AlertChoiceViewController`, or `AlertDocViewController`
 */
class AlertViewController: UIViewController {
    private let actionString: String
    private let hasCancelButton: Bool
    private let destructive: Bool
    let loading: Bool
    private let handler: (() -> Void)?
    private let cancelHandler: (() -> Void)?

    var contentView = UIView()
    var alertView: UIView!
    var actionButton: UIButton!
    var cancelButton: UIButton!
    var centerConstraint: NSLayoutConstraint!

    init(title: String, action: String, hasCancelButton: Bool = true, destructive: Bool = false, loading: Bool = false, handler: (() -> Void)?, cancelHandler: (() -> Void)? = nil) {
        self.actionString = action
        self.hasCancelButton = hasCancelButton
        self.destructive = destructive
        self.loading = loading
        self.handler = handler
        self.cancelHandler = cancelHandler
        super.init(nibName: nil, bundle: nil)
        self.title = title
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Background
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)

        // Alert view
        alertView = UIView()
        alertView.cornerRadius = UIConstants.alertCornerRadius
        alertView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
        alertView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(alertView)

        // Title label
        let titleLabel = IKLabel()
        titleLabel.text = title
        titleLabel.style = .header3
        titleLabel.sizeToFit()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(titleLabel)

        // Content view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(contentView)

        // Action button
        actionButton = UIButton(type: .system)
        actionButton.setTitle(actionString, for: .normal)
        actionButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: UIFontMetrics.default.scaledValue(for: 15))
        if destructive {
            actionButton.tintColor = .systemRed
        }
        actionButton.sizeToFit()
        actionButton.addTarget(self, action: #selector(action), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(actionButton)

        // Cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle(KDriveStrings.Localizable.buttonCancel, for: .normal)
        cancelButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: UIFontMetrics.default.scaledValue(for: 15))
        cancelButton.sizeToFit()
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        if hasCancelButton {
            alertView.addSubview(cancelButton)
        }

        // Constraints
        centerConstraint = alertView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        centerConstraint.isActive = true
        let leading = alertView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24)
        leading.priority = UILayoutPriority(499)
        leading.isActive = true
        let trailing = alertView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        trailing.priority = UILayoutPriority(499)
        trailing.isActive = true
        var constraints = [
            alertView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alertView.widthAnchor.constraint(greaterThanOrEqualToConstant: 272),
            alertView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            alertView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            alertView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            titleLabel.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: 24),
            titleLabel.topAnchor.constraint(equalTo: alertView.topAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 24),
            contentView.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -24),
            contentView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            actionButton.widthAnchor.constraint(equalToConstant: actionButton.bounds.width),
            actionButton.heightAnchor.constraint(equalToConstant: actionButton.bounds.height),
            actionButton.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -24),
            actionButton.topAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 16),
            actionButton.bottomAnchor.constraint(equalTo: alertView.bottomAnchor, constant: -16)
        ]
        if hasCancelButton {
            constraints.append(contentsOf: [
                cancelButton.widthAnchor.constraint(equalToConstant: cancelButton.bounds.width),
                cancelButton.heightAnchor.constraint(equalToConstant: cancelButton.bounds.height),
                cancelButton.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -16),
                cancelButton.topAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 16),
                cancelButton.bottomAnchor.constraint(equalTo: alertView.bottomAnchor, constant: -16)
                ])
        }
        NSLayoutConstraint.activate(constraints)
    }

    /// Set or unset the action button to loading state
    func setLoading(_ loading: Bool) {
        actionButton.setLoading(loading, style: .gray)
        cancelButton.isEnabled = !loading
    }

    // MARK: - Actions

    @objc func cancel() {
        dismiss(animated: true)
        cancelHandler?()
    }

    @objc func action() {
        if loading {
            setLoading(true)
            DispatchQueue.global(qos: .userInitiated).async {
                self.handler?()
                DispatchQueue.main.async {
                    self.setLoading(false)
                    self.dismiss(animated: true)
                }
            }
        } else {
            dismiss(animated: true)
            handler?()
        }
    }

}
