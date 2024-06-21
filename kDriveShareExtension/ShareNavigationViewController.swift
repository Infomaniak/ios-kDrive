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

import InfomaniakCoreUI
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import UIKit
import VersionChecker

final class ShareNavigationViewController: TitleSizeAdjustingNavigationController {
    /// Making sure the DI is registered at a very early stage of the app launch.
    private let dependencyInjectionHook = EarlyDIHook(context: .shareExtension)

    // Not lazy to force init of the object early, and set a userID in Sentry
    @InjectService var accountManager: AccountManageable

    override public func viewDidLoad() {
        // log
        super.viewDidLoad()
        // Modify sheet size on iPadOS, property is ignored on iOS
        preferredContentSize = CGSize(width: 540, height: 620)
        Logging.initLogging()

        let saveViewController = SaveFileViewController.instantiate(driveFileManager: accountManager.currentDriveFileManager)
        let attachments = fetchAttachments()
        guard !attachments.isEmpty else {
            dismiss(animated: true)
            return
        }

        saveViewController.itemProviders = attachments
        viewControllers = [saveViewController]

        Task {
            try? await checkAppVersion()
        }
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        guard let extensionContext else {
            return
        }
        extensionContext.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func checkAppVersion() async throws {
        guard try await VersionChecker.standard.checkAppVersionStatus() == .updateIsRequired else { return }
        Task { @MainActor in
            let updateRequiredViewController = DriveUpdateRequiredViewController()
            updateRequiredViewController.dismissHandler = { [weak self] in
                self?.dismiss(animated: true)
            }
            viewControllers = [updateRequiredViewController]
        }
    }
}
