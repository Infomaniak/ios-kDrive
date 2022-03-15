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

import kDriveResources
import UIKit

class SelectView: UIView {
    class MultipleSelectionActionButton: UIButton {
        private(set) var action: MultipleSelectionAction
        private var onTap: () -> Void

        init(action: MultipleSelectionAction, onTap: @escaping () -> Void) {
            self.action = action
            self.onTap = onTap
            super.init(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
            addTarget(self, action: #selector(didTap), for: .touchUpInside)
            setImage(action.icon.image, for: .normal)
            accessibilityLabel = action.name
            isEnabled = action.enabled
        }

        @objc private func didTap() {
            onTap()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var actionsView: UIStackView!

    weak var delegate: FilesHeaderViewDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 22), weight: .bold)
        titleLabel.accessibilityTraits = .header
    }

    func setActions(_ actions: [MultipleSelectionAction]) {
        actionsView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for action in actions {
            var actionButton: MultipleSelectionActionButton!
            actionButton = MultipleSelectionActionButton(action: action) { [weak self] in
                self?.delegate?.multipleSelectionActionButtonPressed(actionButton)
            }
            actionsView.addArrangedSubview(actionButton)
        }
    }

    func updateTitle(_ count: Int) {
        titleLabel.text = KDriveResourcesStrings.Localizable.fileListMultiSelectedTitle(count)
    }
}
