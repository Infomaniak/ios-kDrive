/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import Foundation
import InfomaniakCoreUI
import kDriveCore
import kDriveResources
import MaterialOutlinedTextField
import UIKit

class TextInputTableViewCell: UITableViewCell {
    let textField = MaterialOutlinedTextField()

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none
        textField.backgroundColor = .systemBackground

        textField.setInfomaniakColors()
        textField.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            textField.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        guard selected != isSelected else {
            return
        }

        super.setSelected(selected, animated: animated)

        if selected {
            textField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        setSelected(false, animated: false)
        textField.text = ""
    }
}
