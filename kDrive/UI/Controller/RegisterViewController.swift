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
import InfomaniakCoreCommonUI
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import kDriveResources
import UIKit
import WebKit

class RegisterViewController: UIViewController {
    @IBOutlet var webView: WKWebView!
    weak var delegate: InfomaniakLoginDelegate?

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var infomaniakLogin: InfomaniakLoginable

    private let progressView = UIProgressView(progressViewStyle: .default)
    private var estimatedProgressObserver: NSKeyValueObservation?

    deinit {
        estimatedProgressObserver?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = KDriveResourcesStrings.Localizable.buttonSignIn
        setupProgressView()
        setupEstimatedProgressObserver()
        webView.load(URLRequest(url: URLConstants.signUp.url))
        webView.navigationDelegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        matomo.track(view: ["Register"])
    }

    private func setupProgressView() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        progressView.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.addSubview(progressView)

        progressView.isHidden = true

        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor),

            progressView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2.0)
        ])
    }

    private func setupEstimatedProgressObserver() {
        estimatedProgressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            self?.progressView.progress = Float(webView.estimatedProgress)
        }
    }

    @IBAction func dismissButtonPressed(_ sender: Any) {
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            for record in records {
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record]) {}
            }
        }
        dismiss(animated: true)
    }

    class func instantiate() -> RegisterViewController {
        return Storyboard.main.instantiateViewController(withIdentifier: "RegisterViewController") as! RegisterViewController
    }

    class func instantiateInNavigationController(delegate: InfomaniakLoginDelegate) -> UINavigationController {
        let registerViewController = instantiate()
        registerViewController.delegate = delegate
        return UINavigationController(rootViewController: registerViewController)
    }
}

// MARK: - WKNavigationDelegate

extension RegisterViewController: WKNavigationDelegate {
    func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        if progressView.isHidden {
            progressView.isHidden = false
        }
        UIView.animate(withDuration: 0.33) {
            self.progressView.alpha = 1.0
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        UIView.animate(withDuration: 0.33,
                       animations: {
                           self.progressView.alpha = 0.0
                       },
                       completion: { isFinished in
                           self.progressView.isHidden = isFinished
                       })
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let host = navigationAction.request.url?.host,
              let kDriveHost = URLConstants.kDriveWeb.url.host,
              let loginHost = infomaniakLogin.config.loginURL.host else {
            decisionHandler(.allow)
            return
        }

        if host == kDriveHost {
            decisionHandler(.cancel)
            if let delegate,
               let navigationController {
                infomaniakLogin.webviewLoginFrom(viewController: navigationController,
                                                 hideCreateAccountButton: true,
                                                 delegate: delegate)
            }
        } else if host == loginHost {
            decisionHandler(.cancel)
            dismiss(animated: true)
        } else {
            decisionHandler(.allow)
        }
    }
}
