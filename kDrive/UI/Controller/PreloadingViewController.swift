/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import UIKit

class PreloadingViewController: UIViewController {
    @LazyInjectService private var accountManager: AccountManageable
    @LazyInjectService private var appNavigable: AppNavigable

    private let currentAccount: ApiToken?

    init() {
        currentAccount = nil
        super.init(nibName: nil, bundle: nil)
    }

    init(currentAccount: ApiToken) {
        self.currentAccount = currentAccount
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let driveImageView: UIImageView = {
        let imageView = UIImageView(image: KDriveAsset.splashscreenKdrive.image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(lessThanOrEqualToConstant: 204).isActive = true
        return imageView
    }()

    private let progressView: UIActivityIndicatorView = {
        let progressView = UIActivityIndicatorView(style: .medium)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.startAnimating()
        return progressView
    }()

    private let splashscreenInfomaniakImageView: UIImageView = {
        let imageView = UIImageView(image: KDriveAsset.splashscreenInfomaniak.image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 178).isActive = true
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KDriveAsset.backgroundColor.color

        setupViews()

        guard let currentAccount else { return }
        preloadAccountAndDrives(account: currentAccount)
    }

    private func setupViews() {
        view.addSubview(driveImageView)
        NSLayoutConstraint.activate([
            driveImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            driveImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -28),
            driveImageView.heightAnchor.constraint(equalToConstant: driveImageView.image!.size.height)
        ])

        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.topAnchor.constraint(equalTo: driveImageView.bottomAnchor, constant: 16)
        ])

        view.addSubview(splashscreenInfomaniakImageView)
        NSLayoutConstraint.activate([
            splashscreenInfomaniakImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            splashscreenInfomaniakImageView.bottomAnchor
                .constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    func preloadAccountAndDrives(account: ApiToken) {
        Task {
            do {
                _ = try await accountManager.updateUser(for: account, registerToken: true)
                _ = try accountManager.getFirstAvailableDriveFileManager(for: account.userId)

                if let currentDriveFileManager = self.accountManager.currentDriveFileManager {
                    let state = RootViewControllerState.mainViewController(driveFileManager: currentDriveFileManager)
                    self.appNavigable.prepareRootViewController(currentState: state, restoration: false)
                } else {
                    self.appNavigable.prepareRootViewController(currentState: .onboarding, restoration: false)
                }
            } catch DriveError.NoDriveError.noDrive {
                let driveErrorViewController = DriveErrorViewController.instantiate(errorType: .noDrive, drive: nil)
                present(driveErrorViewController, animated: true)
            } catch DriveError.NoDriveError.blocked(let drive), DriveError.NoDriveError.maintenance(let drive) {
                let driveErrorNavigationViewController = DriveErrorViewController.instantiateInNavigationController(
                    errorType: drive.isInTechnicalMaintenance ? .maintenance : .blocked,
                    drive: drive
                )
                driveErrorNavigationViewController.modalPresentationStyle = .fullScreen
                present(driveErrorNavigationViewController, animated: true)
            } catch {
                SentryDebug.logPreloadingAccountError(error: error, origin: "PreloadingViewController")
                accountManager.removeTokenAndAccountFor(userId: account.userId)
                self.appNavigable.prepareRootViewController(currentState: .onboarding, restoration: false)
            }
        }
    }
}

@available(iOS 17, *)
#Preview {
    PreloadingViewController(currentAccount: ApiToken(
        accessToken: "",
        expiresIn: 0,
        refreshToken: "",
        scope: "",
        tokenType: "",
        userId: 0,
        expirationDate: Date()
    ))
}
