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

import InfomaniakCoreUIKit
import kDriveResources
import UIKit

/// Alert with choices
public class AlertChoiceViewController: AlertViewController {
    private let choices: [String]
    private var selectedIndex: Int
    private let handler: ((Int) -> Void)?
    private var checkmarks = [UIImageView]()

    static var emptyCheckmarkImage: UIImage = {
        let size = CGSize(width: 22, height: 22)
        let lineWidth = 1.0
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            ctx.cgContext.setFillColor(KDriveResourcesAsset.backgroundCardViewColor.color.cgColor)
            ctx.cgContext.setStrokeColor(KDriveResourcesAsset.borderColor.color.cgColor)
            ctx.cgContext.setLineWidth(lineWidth)

            let diameter = min(size.width, size.height) - lineWidth
            let rect = CGRect(x: (size.width - diameter) / 2, y: (size.height - diameter) / 2, width: diameter, height: diameter)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fillStroke)
        }
    }()

    /**
     Creates a new alert with choices.
     - Parameters:
        - title: Title of the alert view
        - choices: Choices to present
        - selected: Index of the selected choice
        - action: Label of the action button
        - loading: If this is set as true, the action button will automatically be set to the loading state while the `handler` is called. In this case, `handler` has to be **synchronous**
        - handler: Closure to execute when the action button is tapped
        - cancelHandler: Closure to execute when the cancel button is tapped
     */
    public init(
        title: String,
        choices: [String],
        selected: Int = 0,
        action: String,
        loading: Bool = false,
        handler: ((Int) -> Void)?,
        cancelHandler: (() -> Void)? = nil
    ) {
        self.choices = choices
        selectedIndex = selected
        self.handler = handler
        super.init(title: title, action: action, loading: loading, handler: nil, cancelHandler: cancelHandler)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        var topAnchor = contentView.topAnchor

        // Choices
        var index = 0
        for choice in choices {
            // Label
            let label = IKLabel()
            label.text = choice
            label.style = .body1
            label.numberOfLines = 0
            label.sizeToFit()
            label.translatesAutoresizingMaskIntoConstraints = false
            // Checkmark
            let image = UIImageView(image: checkmarkImage(for: index))
            image.translatesAutoresizingMaskIntoConstraints = false
            checkmarks.append(image)
            // Container view
            let view = UIView()
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            view.tag = index
            view.isUserInteractionEnabled = true
            view.addGestureRecognizer(tap)
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
            view.addSubview(image)
            view.addSubview(label)
            // Constraints
            let constraints = [
                view.topAnchor.constraint(equalTo: topAnchor, constant: topAnchor == contentView.topAnchor ? 0 : 24),
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                image.topAnchor.constraint(equalTo: view.topAnchor),
                image.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                image.widthAnchor.constraint(equalToConstant: 22),
                image.heightAnchor.constraint(equalToConstant: 22),
                label.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                label.topAnchor.constraint(equalTo: view.topAnchor),
                label.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]
            NSLayoutConstraint.activate(constraints)
            topAnchor = view.bottomAnchor
            index += 1
        }
        topAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
    }

    private func checkmarkImage(for index: Int) -> UIImage {
        return index == selectedIndex ? KDriveResourcesAsset.check.image : AlertChoiceViewController.emptyCheckmarkImage
    }

    // MARK: - Actions

    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            if let index = sender.view?.tag {
                selectedIndex = index
                var index = 0
                for checkmark in checkmarks {
                    checkmark.image = checkmarkImage(for: index)
                    index += 1
                }
            }
        }
    }

    @objc override public func action() {
        if loading {
            setLoading(true)
            DispatchQueue.global(qos: .userInitiated).async {
                self.handler?(self.selectedIndex)
                Task { @MainActor in
                    self.setLoading(false)
                    self.dismiss(animated: true)
                }
            }
        } else {
            handler?(selectedIndex)
            dismiss(animated: true)
        }
    }
}
