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

import InfomaniakCore
import kDriveCore
import UIKit
import WebKit

class DeleteAccountViewController: UIViewController {
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var progressView: UIProgressView!

    var driveFileManager: DriveFileManager!

    private var progressObserver: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let url = ApiRoutes.mobileLogin(url: URLConstants.deleteAccount.url.absoluteString) {
            if let token = driveFileManager.apiFetcher.currentToken {
                var request = URLRequest(url: url)
                request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
                webView.load(request)
                setUpWebview()
            }
        }

        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName, "DeleteAccount"])
    }

    deinit {
        progressObserver?.invalidate()
    }

    private func setUpWebview() {
        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] _, value in
            guard let newValue = value.newValue else { return }
            self?.progressView.isHidden = newValue == 1
            self?.progressView.setProgress(Float(newValue), animated: true)
        }

        webView.navigationDelegate = self
    }

    @IBAction func close(_ sender: Any) {
        dismiss(animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension DeleteAccountViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let urlString = url.absoluteString
            if urlString.starts(with: "https://\(ApiEnvironment.current.managerHost)/v3/mobile_login")
                || urlString.starts(with: "https://manager.infomaniak.com")
                || navigationAction.targetFrame?.isMainFrame == false {
                decisionHandler(.allow)
                return
            }
        }
        decisionHandler(.cancel)
        dismiss(animated: true)
    }
}
