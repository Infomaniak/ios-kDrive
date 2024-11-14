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

class MessageTableViewCell: InsetTableViewCell {
    @IBOutlet var messageTextView: UITextView!

    var textDidChange: ((String?) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()

        messageTextView.delegate = self
    }
}

// MARK: - UITextViewDelegate

extension MessageTableViewCell: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == KDriveResourcesStrings.Localizable.fileShareAddMessage {
            textView.text = ""
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        textDidChange?(textView.text)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = KDriveResourcesStrings.Localizable.fileShareAddMessage
        }
    }
}
