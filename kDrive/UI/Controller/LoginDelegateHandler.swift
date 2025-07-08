/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDeviceCheck
import InfomaniakDI
import InfomaniakLogin
import InterAppLogin
import kDriveCore
import kDriveResources

public final class LoginDelegateHandler: InfomaniakLoginDelegate {
    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var deeplinkService: DeeplinkServiceable
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var router: AppNavigable
    @LazyInjectService var sharedWithMeService: SharedWithMeServiceable
    @LazyInjectService var tokenService: InfomaniakNetworkLoginable

    private var deviceCheckEnvironment: InfomaniakDeviceCheck.Environment {
        switch ApiEnvironment.current {
        case .prod:
            return .prod
        case .preprod:
            return .preprod
        default:
            fatalError("Unknown environment")
        }
    }
  
    var didStartLoginCallback: (() -> Void)?
    var didCompleteLoginCallback: (() -> Void)?
    var didFailLoginWithErrorCallback: ((Error) -> Void)?

    public init(didCompleteLoginCallback: (() -> Void)? = nil) {
        self.didCompleteLoginCallback = didCompleteLoginCallback
    }

    @MainActor public func didCompleteLoginWith(code: String, verifier: String) {
        guard let topMostViewController = router.topMostViewController else { return }

        matomo.track(eventWithCategory: .account, name: "loggedIn")
        let previousAccount = accountManager.currentAccount

        didStartLoginCallback?()

        Task {
            do {
                _ = try await accountManager.createAndSetCurrentAccount(code: code, codeVerifier: verifier)
                guard let currentDriveFileManager = accountManager.currentDriveFileManager else {
                    throw DriveError.NoDriveError.noDriveFileManager
                }

                self.matomo.connectUser(userId: accountManager.currentUserId.description)
                goToMainScreen(with: currentDriveFileManager)
            } catch {
                didCompleteLoginWithError(error, previousAccount: previousAccount, topMostViewController: topMostViewController)
            }

            didCompleteLoginCallback?()
        }
    }

    @MainActor
    public func login(with accounts: [ConnectedAccount]) {
        guard let topMostViewController = router.topMostViewController else { return }

        matomo.track(eventWithCategory: .account, name: "loggedIn")

        didStartLoginCallback?()

        Task {
            await deviceAttestationAndLogin(with: accounts, topMostViewController: topMostViewController)
        }
    }

    private func deviceAttestationAndLogin(with accounts: [ConnectedAccount], topMostViewController: UIViewController) async {
        let previousAccount = accountManager.currentAccount

        do {
            let attestationToken = try await generateAttestationTokenForDevice()

            for account in accounts {
                let derivatedToken = try await tokenService.derivateApiToken(
                    using: account.token,
                    attestationToken: attestationToken
                )

                _ = try await accountManager.createAndSetCurrentAccount(token: derivatedToken)
                guard let currentDriveFileManager = accountManager.currentDriveFileManager else {
                    throw DriveError.NoDriveError.noDriveFileManager
                }

                matomo.connectUser(userId: accountManager.currentUserId.description)
                await goToMainScreen(with: currentDriveFileManager)
            }

            Task { @MainActor in
                didCompleteLoginCallback?()
            }
        } catch {
            Task { @MainActor in
                didCompleteLoginWithError(
                    error,
                    previousAccount: previousAccount,
                    topMostViewController: topMostViewController
                )
            }
        }
    }

    private func generateAttestationTokenForDevice() async throws -> String {
        return try await InfomaniakDeviceCheck(environment: deviceCheckEnvironment)
            .generateAttestationFor(
                targetUrl: FactoryService.loginConfig.loginURL.appendingPathComponent("token"),
                bundleId: "com.infomaniak.drive",
                bypassValidation: ApiEnvironment.current == .prod ? false : true
            )
    }

    @MainActor private func goToMainScreen(with driveFileManager: DriveFileManager) {
        UserDefaults.shared.legacyIsFirstLaunch = false
        UserDefaults.shared.numberOfConnections = 1
        _ = router.showMainViewController(driveFileManager: driveFileManager, selectedIndex: nil)
        deeplinkService.processDeeplinksPostAuthentication()
    }

    private func didCompleteLoginWithError(_ error: Error,
                                           previousAccount: Account?,
                                           topMostViewController: UIViewController) {
        DDLogError("Error on didCompleteLoginWith \(error)")

        if let previousAccount {
            accountManager.switchAccount(newAccount: previousAccount)
        }

        if let noDriveError = error as? InfomaniakCore.ApiError, noDriveError.code == DriveError.noDrive.code {
            let driveErrorVC = DriveErrorViewController.instantiate(errorType: .noDrive, drive: nil)
            topMostViewController.present(driveErrorVC, animated: true)
        } else if let driveError = error as? DriveError.NoDriveError, case .maintenance(let drive) = driveError {
            let driveErrorVC = DriveErrorViewController.instantiate(errorType: .maintenance, drive: drive)
            topMostViewController.present(driveErrorVC, animated: true)
        } else if let driveError = error as? DriveError,
                  driveError == .noDrive
                  || driveError == .productMaintenance
                  || driveError == .driveMaintenance
                  || driveError == .blocked {
            let errorViewType: DriveErrorViewController.DriveErrorViewType
            switch driveError {
            case .productMaintenance, .driveMaintenance:
                errorViewType = .maintenance
            case .blocked:
                errorViewType = .blocked
            default:
                errorViewType = .noDrive
            }

            let driveErrorVC = DriveErrorViewController.instantiate(errorType: errorViewType, drive: nil)
            topMostViewController.present(driveErrorVC, animated: true)
        } else {
            let metadata = [
                "Underlying Error": error.asAFError?.underlyingError.debugDescription ?? "Not an AFError"
            ]
            SentryDebug.capture(error: error, context: metadata, contextKey: "Error")

            topMostViewController.okAlert(
                title: KDriveResourcesStrings.Localizable.errorTitle,
                message: KDriveResourcesStrings.Localizable.errorConnection
            )
        }
    }

    public func didFailLoginWith(error: Error) {
        didFailLoginWithErrorCallback?(error)
    }
}
