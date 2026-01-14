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
import HighlightSwift
import kDriveCore
import kDriveResources
import MarkdownKit
import UIKit

/// Something to read a file outside of the main actor
struct CodePreviewWorker {
    /// The JS text preview library will blow up in memory usage if the input is larger
    static let textFilePreviewCap = 512_000

    func readDataToStringInferEncoding(localUrl: URL) async throws -> String {
        let rawData = try Data(contentsOf: localUrl, options: .alwaysMapped)

        let dataToDeserialize: Data
        if rawData.count > Self.textFilePreviewCap {
            dataToDeserialize = rawData.prefix(Self.textFilePreviewCap)
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
        guard isCode && previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else {
            return
        }
        Task {
            let lightModeText = textView.text ?? ""
            textView.text = ""
            activityView.startAnimating()
            try? await displayCode(for: lightModeText)
            activityView.stopAnimating()
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

    func configure(with file: File) {
        textView.text = ""
        activityView.startAnimating()

        let localUrl = file.localUrl
        let fileId = file.id

        Task {
            do {
                let contentString = try await codePreviewWorker.readDataToStringInferEncoding(localUrl: localUrl)
                try await displayContent(with: file, content: contentString)
            } catch {
                DDLogError("Failed to read file content: \(error)")
                previewDelegate?.errorWhilePreviewing(fileId: fileId, error: error)
            }
        }
    }

    private func displayContent(with file: File, content: String) async throws {
        if file.extension == "md" || file.extension == "markdown" {
            await displayMarkdown(for: content)
            isCode = false
        } else {
            try await displayCode(for: content)
            isCode = true
        }
        activityView.stopAnimating()
    }

    private func displayMarkdown(for content: String) async {
        let attributedText = await markdownParser.attributedString(for: content)
        textView.attributedText = NSAttributedString(attributedText)
    }

    private func displayCode(for content: String) async throws {
        let theme: HighlightColors = UITraitCollection.current.userInterfaceStyle == .light ? .light(.xcode) : .dark(.xcode)
        let attributedText = try await Highlight().attributedText(content, colors: theme)
        textView.attributedText = NSAttributedString(attributedText)
    }
}

extension MarkdownParser {
    func attributedString(for rawMarkdown: String) async -> AttributedString {
        return AttributedString(parse(rawMarkdown))
    }
}
