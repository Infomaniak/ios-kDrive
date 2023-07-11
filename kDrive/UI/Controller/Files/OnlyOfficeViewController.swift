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
import kDriveResources
import Sentry
import UIKit
import WebKit

class OnlyOfficeViewController: UIViewController {
    var driveFileManager: DriveFileManager!
    var file: File!
    weak var previewParent: PreviewViewController?

    var webView: WKWebView!
    let progressView = UIProgressView()

    private var progressObserver: NSKeyValueObservation?

    class func open(driveFileManager: DriveFileManager, file: File, viewController: UIViewController) {
        guard file.isOfficeFile else { return }

        if let newExtension = file.conversion?.onylofficeExtension {
            let driveFloatingPanelController = UnsupportedExtensionFloatingPanelViewController.instantiatePanel()
            let attrString = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.notSupportedExtensionDescription(file.name), boldText: file.name, color: KDriveResourcesAsset.titleColor.color)
            guard let floatingPanelViewController = driveFloatingPanelController.contentViewController as? UnsupportedExtensionFloatingPanelViewController else { return }
            floatingPanelViewController.titleLabel.text = KDriveResourcesStrings.Localizable.notSupportedExtensionTitle(file.extension)
            floatingPanelViewController.descriptionLabel.attributedText = attrString
            floatingPanelViewController.rightButton.setTitle(KDriveResourcesStrings.Localizable.buttonCreateOnlyOfficeCopy(newExtension), for: .normal)
            floatingPanelViewController.cancelHandler = { _ in
                viewController.dismiss(animated: true)
                let onlyOfficeViewController = OnlyOfficeViewController.instantiate(driveFileManager: driveFileManager, file: file, previewParent: viewController as? PreviewViewController)
                viewController.present(onlyOfficeViewController, animated: true)
            }
            floatingPanelViewController.actionHandler = { sender in
                sender.setLoading(true)
                Task { [proxyFile = file.proxify()] in
                    do {
                        let newFile = try await driveFileManager.apiFetcher.convert(file: proxyFile)
                        sender.setLoading(false)
                        if let parent = file.parent {
                            driveFileManager.notifyObserversWith(file: parent)
                        }
                        viewController.dismiss(animated: true)
                        open(driveFileManager: driveFileManager, file: newFile, viewController: viewController)
                    } catch {
                        UIConstants.showSnackBarIfNeeded(error: error)
                    }
                }
            }
            viewController.present(driveFloatingPanelController, animated: true)
        } else {
            let onlyOfficeViewController = OnlyOfficeViewController.instantiate(driveFileManager: driveFileManager, file: file, previewParent: viewController as? PreviewViewController)
            viewController.present(onlyOfficeViewController, animated: true)
        }
    }

    class func instantiate(driveFileManager: DriveFileManager, file: File, previewParent: PreviewViewController?) -> OnlyOfficeViewController {
        let onlyOfficeViewController = OnlyOfficeViewController()
        onlyOfficeViewController.driveFileManager = driveFileManager
        onlyOfficeViewController.file = file
        onlyOfficeViewController.previewParent = previewParent
        onlyOfficeViewController.modalPresentationStyle = .fullScreen
        return onlyOfficeViewController
    }

    override func loadView() {
        /*
         With iOS 16.1, WKWebView cannot handle SharedWorkers
         We have to use this workaround while waiting for a solution from Apple
         https://developer.apple.com/forums/thread/718757?answerId=734292022#734292022
         */
        let webConfiguration = WKWebViewConfiguration()
        let dropSharedWorkersScript = WKUserScript(source: "delete window.SharedWorker;", injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: false)
        webConfiguration.userContentController.addUserScript(dropSharedWorkersScript)
        // Force mobile mode for better usage on iPadOS
        webConfiguration.defaultWebpagePreferences.preferredContentMode = .mobile
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.scrollView.isScrollEnabled = false
        webView.uiDelegate = self
        webView.navigationDelegate = self

        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] _, value in
            guard let newValue = value.newValue else {
                return
            }
            self?.progressView.isHidden = newValue == 1
            self?.progressView.setProgress(Float(newValue), animated: true)
        }
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
        if let officeUrl = file.officeUrl, let url = ApiRoutes.mobileLogin(url: officeUrl.absoluteString) {
            if let token = driveFileManager.apiFetcher.currentToken {
                driveFileManager.apiFetcher.performAuthenticatedRequest(token: token) { token, _ in
                    if let token = token {
                        var request = URLRequest(url: url)
                        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
                        DispatchQueue.main.async {
                            self.webView.load(request)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showErrorMessage()
                        }
                    }
                }
            } else {
                showErrorMessage()
            }
        } else {
            showErrorMessage(context: ["URL": "nil"])
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.preview.displayName, "OnlyOffice"])
        MatomoUtils.trackPreview(file: file)
    }

    deinit {
        progressObserver?.invalidate()
    }

    private func showErrorMessage(context: [String: Any] = [:]) {
        SentrySDK.capture(message: "Failed to load office editor") { scope in
            scope.setContext(value: context, key: "office")
        }
        dismiss(animated: true) {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorLoadingOfficeEditor)
        }
    }

    private func dismiss() {
        dismiss(animated: true)
    }
}

// MARK: - WKUIDelegate

extension OnlyOfficeViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        if navigationAction.targetFrame == nil && url.host == ApiEnvironment.current.driveHost {
            dismiss()
            return nil
        }

        // Open target="_blank" links outside drive in Safari
        if navigationAction.targetFrame == nil {
            UIApplication.shared.open(url)
        }
        return nil
    }
}

// MARK: - WKNavigationDelegate

extension OnlyOfficeViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            let urlString = url.absoluteString
            if url == file.officeUrl
                || urlString.starts(with: "https://\(ApiEnvironment.current.managerHost)/v3/mobile_login")
                // Validate all requests that will be displayed in an iframe
                || navigationAction.targetFrame?.isMainFrame == false {
                // HACK: Print/download a file if the URL contains "/output." because `shouldPerformDownload` doesn't work
                if urlString.contains("/output.") {
                    if UIPrintInteractionController.canPrint(url) {
                        let printController = UIPrintInteractionController()
                        printController.printingItem = url
                        printController.present(animated: true)
                    } else {
                        // Download
                        UIApplication.shared.open(url)
                    }
                    decisionHandler(.cancel)
                    return
                } else {
                    decisionHandler(.allow)
                    return
                }
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
            showErrorMessage(context: ["URL": navigationResponse.response.url?.absoluteString ?? "", "Status code": statusCode])
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showErrorMessage(context: ["Error": error.localizedDescription])
    }
}
