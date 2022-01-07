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

import CocoaLumberjackSwift
import Highlightr
import kDriveCore
import UIKit

class CodePreviewCollectionViewCell: PreviewCollectionViewCell {
    @IBOutlet weak var textView: UITextView!

    private let highlightr = Highlightr()

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setTheme()
        // Update content
        textView.attributedText = highlightr?.highlight(textView.text)
    }

    private func setTheme() {
        let theme: String
        switch UITraitCollection.current.userInterfaceStyle {
        case .light:
            theme = "a11y-light"
        case .dark:
            theme = "a11y-dark"
        default:
            theme = "default"
        }
        highlightr?.setTheme(to: theme)
    }

    func configure(with file: File) {
        do {
            // Read file
            let content = try String(contentsOf: file.localUrl)
            // Display content
            setTheme()
            textView.attributedText = highlightr?.highlight(content)
        } catch {
            DDLogError("Failed to read file content: \(error)")
            previewDelegate?.errorWhilePreviewing(fileId: file.id, error: error)
        }
    }
}
