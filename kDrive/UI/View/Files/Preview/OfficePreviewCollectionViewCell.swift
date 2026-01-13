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

import kDriveCore
import UIKit
import WebKit

class OfficePreviewCollectionViewCell: PreviewCollectionViewCell {
    @IBOutlet var documentPreview: WKWebView!
    private var fileId: Int?

    override func awakeFromNib() {
        super.awakeFromNib()
        fileId = nil
        documentPreview.alpha = 0
        tapGestureRecognizer.delegate = self
        documentPreview.configuration.websiteDataStore = .nonPersistent()
        documentPreview.scrollView.showsVerticalScrollIndicator = false
        documentPreview.navigationDelegate = self
        documentPreview.addShadow()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        documentPreview.alpha = 0
        documentPreview.load(URLRequest(url: URL(string: "about:blank")!))
    }

    override func configureWith(file: File) {
        fileId = file.id
        if file.uti.conforms(to: .plainText) {
            // Load data for plain text to have correct encoding
            do {
                let data = try Data(contentsOf: file.localUrl)
                documentPreview.load(
                    data,
                    mimeType: file.uti.preferredMIMEType ?? "text/plain",
                    characterEncodingName: "UTF8",
                    baseURL: file.localUrl
                )
            } catch {
                // Fallback on file loading
                documentPreview.loadFileURL(file.localUrl, allowingReadAccessTo: file.localUrl)
            }
        } else {
            documentPreview.loadFileURL(file.localUrl, allowingReadAccessTo: file.localUrl)
        }
    }
}

extension OfficePreviewCollectionViewCell: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}

// MARK: - WKNavigationDelegate

extension OfficePreviewCollectionViewCell: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                await UIApplication.shared.open(url)
            }
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        UIView.animate(withDuration: 0.25) {
            self.documentPreview.alpha = 1
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let fileId else { return }
        previewDelegate?.errorWhilePreviewing(fileId: fileId, error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard let fileId else { return }
        previewDelegate?.errorWhilePreviewing(fileId: fileId, error: error)
    }
}
