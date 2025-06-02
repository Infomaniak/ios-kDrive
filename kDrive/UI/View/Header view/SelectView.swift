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

class SelectView: UIView {
    class MultipleSelectionActionButton: UIButton {
        private(set) var action: MultipleSelectionAction
        private weak var delegate: FilesHeaderViewDelegate?

        init(action: MultipleSelectionAction, delegate: FilesHeaderViewDelegate?) {
            self.action = action
            self.delegate = delegate
            super.init(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
            addTarget(self, action: #selector(didTap), for: .touchUpInside)
            setImage(action.icon.image, for: .normal)
            accessibilityLabel = action.name
            isEnabled = action.enabled
        }

        @objc private func didTap() {
            delegate?.multipleSelectionActionButtonPressed(self)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    @IBOutlet var titleLabel: IKLabel!
    @IBOutlet var actionsView: UIStackView!
    var buttonTint: UIColor?

    weak var delegate: FilesHeaderViewDelegate?

    class func instantiate() -> SelectView {
        let view = Bundle.main.loadNibNamed("SelectView", owner: nil, options: nil)![0] as! SelectView
        return view
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 22), weight: .bold)
        titleLabel.accessibilityTraits = .header
        titleLabel.text = ""
    }

    func setActions(_ actions: [MultipleSelectionAction]) {
        actionsView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for action in actions {
            let actionButton = MultipleSelectionActionButton(action: action, delegate: delegate)
            actionButton.tintColor = buttonTint
            actionsView.addArrangedSubview(actionButton)
        }
    }

    func updateTitle(_ count: Int) {
        titleLabel.text = KDriveResourcesStrings.Localizable.fileListMultiSelectedTitle(count)
    }
}
