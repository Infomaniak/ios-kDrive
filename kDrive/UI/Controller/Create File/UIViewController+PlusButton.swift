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
    func makePlusBarButtonItem(
        driveFileManager: DriveFileManager,
        currentFolder: File?,
        presentedAboveFileList: Bool = false,
        onPresent: @escaping (PlusButtonFloatingPanelViewController) -> Void
    ) -> UIBarButtonItem {
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
        return addItem
    }

    @available(iOS 27.1, *)
    func installHingePinnedPlusButton(
        driveFileManager: DriveFileManager,
        currentFolder: File?,
        presentedAboveFileList: Bool = false,
        onPresent: @escaping (PlusButtonFloatingPanelViewController) -> Void
    ) {
        let addItem = makePlusBarButtonItem(
            driveFileManager: driveFileManager,
            currentFolder: currentFolder,
            presentedAboveFileList: presentedAboveFileList,
            onPresent: onPresent
        )

        #if !ISEXTENSION
        if MainTabViewController.isHingeClosed {
            setPlusVisible(addItem: addItem, visible: true)
        }
        #endif

        view.addInteraction(UIHingeInteraction { [weak self] _, _ in
            guard let self else { return }
            setPlusVisible(
                addItem: addItem,
                visible: splitViewController?.traitCollection.horizontalSizeClass == .compact
            )
        })
    }

    private func setPlusVisible(addItem: UIBarButtonItem, visible: Bool) {
        var items = (navigationItem.rightBarButtonItems ?? []).filter { $0 != addItem }
        if visible { items.insert(addItem, at: 0) }
        guard items != (navigationItem.rightBarButtonItems ?? []) else { return }
        navigationItem.rightBarButtonItems = items
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
