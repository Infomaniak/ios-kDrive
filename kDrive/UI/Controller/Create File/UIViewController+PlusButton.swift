/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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
import kDriveResources
import UIKit

extension UIViewController {
    @available(iOS 27.1, *)
    func installHingePinnedPlusButton(
        driveFileManager: DriveFileManager,
        currentFolder: File?,
        presentedAboveFileList: Bool = false,
        onPresent: @escaping (PlusButtonFloatingPanelViewController) -> Void
    ) {
        let addItem = UIBarButtonItem(
            title: KDriveResourcesStrings.Localizable.buttonAdd,
            image: KDriveResourcesAsset.plus.image,
            primaryAction: UIAction { [weak self] _ in
                guard let self, let currentFolder else { return }
                #if !ISEXTENSION
                let panel = presentPlusButtonPanel(
                    driveFileManager: driveFileManager,
                    folder: currentFolder,
                    presentedAboveFileList: presentedAboveFileList
                )
                onPresent(panel)
                #endif
            }
        )
        addItem.style = .prominent
        addItem.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonAdd
        addItem.axisBehavior = .verticalPreferred

        let group = UIBarButtonItemGroup(barButtonItems: [addItem], representativeItem: nil)

        #if !ISEXTENSION
        if (tabBarController as? MainTabViewController)?.isHingeClosed == true {
            navigationItem.pinnedTrailingGroup = group
        }
        #endif

        view.addInteraction(UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            if update.hinge?.status == .closed {
                if navigationItem.pinnedTrailingGroup != group {
                    navigationItem.pinnedTrailingGroup = group
                }
            } else {
                navigationItem.pinnedTrailingGroup = nil
            }
        })
    }

    func presentPlusButtonPanel(
        driveFileManager: DriveFileManager,
        folder: File,
        presentedAboveFileList: Bool
    ) -> PlusButtonFloatingPanelViewController {
        let plusButtonFloatingPanel = PlusButtonFloatingPanelViewController(
            driveFileManager: driveFileManager,
            folder: folder,
            presentedAboveFileList: presentedAboveFileList
        )
        present(plusButtonFloatingPanel, animated: true)
        return plusButtonFloatingPanel
    }
}
