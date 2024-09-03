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

import InfomaniakDI
import kDriveCore
import UIKit

struct LaunchPanel: Comparable {
    let makePanelController: () -> DriveFloatingPanelController
    let displayCondition: () -> Bool
    let onDisplay: (() -> Void)?
    let priority: Int

    static func < (lhs: LaunchPanel, rhs: LaunchPanel) -> Bool {
        return lhs.priority < rhs.priority
    }

    static func == (lhs: LaunchPanel, rhs: LaunchPanel) -> Bool {
        return lhs.priority == rhs.priority
    }

    init(
        makePanelController: @escaping () -> DriveFloatingPanelController,
        displayCondition: @autoclosure @escaping () -> Bool,
        onDisplay: (() -> Void)? = nil,
        priority: Int
    ) {
        self.makePanelController = makePanelController
        self.displayCondition = displayCondition
        self.onDisplay = onDisplay
        self.priority = priority
    }
}

class LaunchPanelsController {
    private var panels: [LaunchPanel] = {
        let betaInvite = LaunchPanel(
            makePanelController: {
                let driveFloatingPanelController = BetaInviteFloatingPanelViewController.instantiatePanel()
                let floatingPanelViewController = driveFloatingPanelController
                    .contentViewController as? BetaInviteFloatingPanelViewController
                floatingPanelViewController?.actionHandler = { _ in
                    UIApplication.shared.open(URLConstants.testFlight.url)
                    driveFloatingPanelController.dismiss(animated: true)
                }
                return driveFloatingPanelController
            },
            displayCondition: !UserDefaults.shared.betaInviteDisplayed && !Bundle.main.isRunningInTestFlight,
            onDisplay: { UserDefaults.shared.betaInviteDisplayed = true },
            priority: 1
        )

        @InjectService var accountManager: AccountManageable
        guard let currentDriveFileManager = accountManager.currentDriveFileManager else {
            // During an account switch, currentDriveFileManager may be nil.
            Log.sceneDelegate("Tried to display save photos floating panel with nil currentDriveFileManager", level: .error)
            return [betaInvite]
        }

        let photoSyncActivation = LaunchPanel(
            makePanelController: {
                let driveFloatingPanelController = SavePhotosFloatingPanelViewController
                    .instantiatePanel(drive: currentDriveFileManager.drive)
                let floatingPanelViewController = driveFloatingPanelController
                    .contentViewController as? SavePhotosFloatingPanelViewController
                floatingPanelViewController?.actionHandler = { @MainActor _ in
                    @InjectService var appNavigable: AppNavigable
                    appNavigable.showPhotoSyncSettings()
                }
                return driveFloatingPanelController
            },
            displayCondition: InjectService<AccountManageable>().wrappedValue.currentDriveFileManager != nil && UserDefaults
                .shared.numberOfConnections == 1 && !InjectService<PhotoLibraryUploader>().wrappedValue.isSyncEnabled,
            priority: 3
        )

        return [betaInvite, photoSyncActivation]
    }()

    /// Pick a panel to display from the list based on the display condition and priority.
    ///
    /// This call should be called on a background queue because we may do some heavy work at some point.
    /// - Returns: The panel to display, if any.
    private func pickPanelToDisplay() -> LaunchPanel? {
        let potentialPanels = panels.filter { $0.displayCondition() }
        return potentialPanels.sorted().reversed().first
    }

    /// Pick and display a panel, if any, on the specified view controller.
    /// - Parameter viewController: View controller to present the panel.
    func pickAndDisplayPanel(viewController: UIViewController) {
        Task {
            guard let panel = self.pickPanelToDisplay() else {
                return
            }

            Task { @MainActor in
                viewController.present(panel.makePanelController(), animated: true, completion: panel.onDisplay)
            }
        }
    }
}
