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

/// Something to read a file outside of the main actor
struct CodePreviewWorker {
    func readDataToStringInferEncoding(localUrl: URL) async throws -> String {
        let rawData = try Data(contentsOf: localUrl, options: .alwaysMapped)

        let dataToDeserialize: Data
        if rawData.count > 512_000 {
            dataToDeserialize = rawData.prefix(512_000)
        } else {
            dataToDeserialize = rawData
        }

        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16BigEndian,
            .utf16LittleEndian,
            .ascii,
            .iso2022JP
        ]

        for encoding in encodings {
            guard let deserializedString = String(data: dataToDeserialize, encoding: encoding) else {
                continue
            }

            return deserializedString
        }

        throw DriveError.unknownError
    }
}

class CodePreviewCollectionViewCell: PreviewCollectionViewCell {
    private let codePreviewWorker = CodePreviewWorker()
    private let activityView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let highlightr = Highlightr()
    private let markdownParser = MarkdownParser(font: UIFontMetrics.default.scaledFont(for: MarkdownParser.defaultFont),
                                                color: .label,
                                                enabledElements: .disabledAutomaticLink)
    private var isCode = true

    @IBOutlet var textView: UITextView!

    override func awakeFromNib() {
        super.awakeFromNib()
        textView.text = ""
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 3, bottom: 8, right: 3)
        markdownParser.code.font = UIFont.monospacedSystemFont(
            ofSize: UIFontMetrics.default.scaledValue(for: MarkdownParser.defaultFont.pointSize),
            weight: .regular
        )
        markdownParser.code.textBackgroundColor = KDriveResourcesAsset.backgroundColor.color
        setupActivityView()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if isCode {
            // Update content
            displayCode(for: textView.text)
        }
    }

    private func setupActivityView() {
        contentView.addSubview(activityView)
        contentView.bringSubviewToFront(activityView)

        activityView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            activityView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
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
        textView.text = ""
        activityView.startAnimating()

        let localUrl = file.localUrl
        let fileId = file.id

        Task {
            do {
                let contentString = try await codePreviewWorker.readDataToStringInferEncoding(localUrl: localUrl)
                displayContent(with: file, content: contentString)
            } catch {
                DDLogError("Failed to read file content: \(error)")
                previewDelegate?.errorWhilePreviewing(fileId: fileId, error: error)
            }
        }
    }

    private func displayContent(with file: File, content: String) {
        activityView.stopAnimating()
        if file.extension == "md" || file.extension == "markdown" {
            displayMarkdown(for: content)
            isCode = false
        } else {
            displayCode(for: content)
            isCode = true
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
