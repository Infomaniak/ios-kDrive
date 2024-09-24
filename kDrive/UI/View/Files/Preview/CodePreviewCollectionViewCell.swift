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
import kDriveResources
import MarkdownKit
import UIKit

class CodePreviewCollectionViewCell: PreviewCollectionViewCell {
    @IBOutlet var textView: UITextView!

    private let highlightr = Highlightr()
    private let markdownParser = MarkdownParser(font: UIFontMetrics.default.scaledFont(for: MarkdownParser.defaultFont),
                                                color: .label,
                                                enabledElements: .disabledAutomaticLink)
    private var isCode = true

    override func awakeFromNib() {
        super.awakeFromNib()
        textView.text = ""
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 3, bottom: 8, right: 3)
        markdownParser.code.font = UIFont.monospacedSystemFont(
            ofSize: UIFontMetrics.default.scaledValue(for: MarkdownParser.defaultFont.pointSize),
            weight: .regular
        )
        markdownParser.code.textBackgroundColor = KDriveResourcesAsset.backgroundColor.color
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if isCode {
            // Update content
            displayCode(for: textView.text)
        }
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
            if file.extension == "md" || file.extension == "markdown" {
                displayMarkdown(for: content)
                isCode = false
            } else {
                displayCode(for: content)
                isCode = true
            }
        } catch {
            DDLogError("Failed to read file content: \(error)")
            previewDelegate?.errorWhilePreviewing(fileId: file.id, error: error)
        }
    }

    private func displayMarkdown(for content: String) {
        textView.attributedText = markdownParser.parse(content)
    }

    private func displayCode(for content: String) {
        setTheme()
        textView.attributedText = highlightr?.highlight(content)
    }
}
