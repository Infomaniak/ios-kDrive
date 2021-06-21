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
import InfomaniakLogin
import kDriveCore

class RegisterViewController: UIViewController {

    @IBOutlet weak var webView: WKWebView!
    weak var delegate: InfomaniakLoginDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = KDriveStrings.Localizable.buttonSignIn
        webView.load(URLRequest(url: URL(string: ApiRoutes.registerIkDriveUser())!))
        webView.navigationDelegate = self
    }

    @IBAction func dismissButtonPressed(_ sender: Any) {
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

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let host = navigationAction.request.url?.host {
            if host == "drive.infomaniak.com" {
                decisionHandler(.cancel)
                if let delegate = delegate,
                    let navigationController = self.navigationController {
                    InfomaniakLogin.webviewLoginFrom(viewController: navigationController, delegate: delegate)
                }
            } else if host == "login.infomaniak.com" {
                decisionHandler(.cancel)
                dismiss(animated: true)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }

}
