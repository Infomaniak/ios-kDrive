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

import DesignSystem
import kDriveCore
import kDriveResources
import KSuite
import SwiftUI
import UIKit

class KSuiteGetProViewController: GenericHostingViewController<KSuiteGetProView> {
    init() {
        super.init(contentView: KSuiteGetProView())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class KSuiteGetProViewCell: UITableViewCell {
    static let reuseIdentifier = "KSuiteGetProViewCell"

    private let customView = KSuiteGetProViewController().view!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.addSubview(customView)

        customView.translatesAutoresizingMaskIntoConstraints = false
        customView.backgroundColor = .clear

        NSLayoutConstraint.activate([
            customView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -IKPadding.mini),
            customView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            customView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: IKPadding.large),
            customView.trailingAnchor.constraint(greaterThanOrEqualTo: contentView.trailingAnchor, constant: -IKPadding.large),
            customView.heightAnchor.constraint(greaterThanOrEqualToConstant: 112)
        ])
    }
}
