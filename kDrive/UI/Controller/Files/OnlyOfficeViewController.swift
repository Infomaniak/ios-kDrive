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

import UIKit
import WebKit
import kDriveCore

class OnlyOfficeViewController: UIViewController, WKNavigationDelegate {
    var file: File!
    weak var previewParent: PreviewViewController?

    var webView: WKWebView!
    let progressView = UIProgressView()

    class func open(driveFileManager: DriveFileManager, file: File, viewController: UIViewController) {
        guard file.isOfficeFile else { return }

        if let newExtension = file.onlyOfficeConvertExtension {
            let driveFloatingPanelController = UnsupportedExtensionFloatingPanelViewController.instantiatePanel()
            let attrString = NSMutableAttributedString(string: KDriveStrings.Localizable.notSupportedExtensionDescription(file.name), boldText: file.name, color: KDriveAsset.titleColor.color)
            guard let floatingPanelViewController = driveFloatingPanelController.contentViewController as? UnsupportedExtensionFloatingPanelViewController else { return }
            floatingPanelViewController.titleLabel.text = KDriveStrings.Localizable.notSupportedExtensionTitle(file.extension)
            floatingPanelViewController.descriptionLabel.attributedText = attrString
            floatingPanelViewController.rightButton.setTitle(KDriveStrings.Localizable.buttonCreateOnlyOfficeCopy(newExtension), for: .normal)
            floatingPanelViewController.cancelHandler = { sender in
                viewController.dismiss(animated: true)
                let onlyOfficeViewController = OnlyOfficeViewController.instantiate(file: file, previewParent: viewController as? PreviewViewController)
                viewController.present(onlyOfficeViewController, animated: true)
            }
            floatingPanelViewController.actionHandler = { sender in
                sender.setLoading(true)
                driveFileManager.apiFetcher.convertFile(file: file) { (response, error) in
                    sender.setLoading(false)
                    if let newFile = response?.data {
                        if let parent = file.parent {
                            driveFileManager.notifyObserversWith(file: parent)
                        }
                        viewController.dismiss(animated: true)
                        open(driveFileManager: driveFileManager, file: newFile, viewController: viewController)
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
                    }
                }
            }
            viewController.present(driveFloatingPanelController, animated: true)
        } else {
            let onlyOfficeViewController = OnlyOfficeViewController.instantiate(file: file, previewParent: viewController as? PreviewViewController)
            viewController.present(onlyOfficeViewController, animated: true)
        }
    }

    class func instantiate(file: File, previewParent: PreviewViewController?) -> OnlyOfficeViewController {
        let onlyOfficeViewController = OnlyOfficeViewController()
        onlyOfficeViewController.file = file
        onlyOfficeViewController.previewParent = previewParent
        onlyOfficeViewController.modalPresentationStyle = .fullScreen
        return onlyOfficeViewController
    }

    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = self
        if #available(iOS 13.0, *) {
            // Force mobile mode for better usage on iPadOS
            webView.configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add progress view
        view.addSubview(progressView)
        progressView.progressViewStyle = .bar
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        progressView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true

        // Load request
        if let url = URL(string: ApiRoutes.mobileLogin(url: ApiRoutes.showOffice(file: file))) {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(AccountManager.instance.currentAccount.token.accessToken)", forHTTPHeaderField: "Authorization")
            webView.load(request)
        } else {
            showErrorMessage()
        }
    }

    private func showErrorMessage() {
        dismiss(animated: true) {
            UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorLoadingOfficeEditor)
        }
    }

    private func dismiss() {
        dismiss(animated: true)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.isHidden = webView.estimatedProgress == 1
            progressView.setProgress(Float(webView.estimatedProgress), animated: true)
        }
    }

    // MARK: - Web view navigation delegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString {
            if url == file.officeUrl?.absoluteString || url.contains("login.infomaniak.com") || url.contains("manager.infomaniak.com/v3/mobile_login") || url.contains("documentserver.drive.infomaniak.com") {
                decisionHandler(.allow)
                return
            }
        }
        decisionHandler(.cancel)
        dismiss()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let statusCode = (navigationResponse.response as? HTTPURLResponse)?.statusCode else {
            decisionHandler(.allow)
            return
        }

        if statusCode == 200 {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            showErrorMessage()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showErrorMessage()
    }
}
