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
import kDriveCore

class FilePresenter {
    weak var viewController: UIViewController?
    weak var floatingPanelViewController: DriveFloatingPanelController?

    var listType: FileListViewController.Type = FileListViewController.self

    var navigationController: UINavigationController? {
        return viewController?.navigationController
    }

    init(viewController: UIViewController, floatingPanelViewController: DriveFloatingPanelController?) {
        self.viewController = viewController
        self.floatingPanelViewController = floatingPanelViewController
    }

    func presentParent(of file: File, driveFileManager: DriveFileManager) {
        if var parent = file.parent {
            // Fix for weird bug: root container of shared with me is not what is expected
            if driveFileManager.drive.sharedWithMe && parent.id == DriveFileManager.constants.rootID {
                parent = DriveFileManager.sharedWithMeRootFile
            }
            present(driveFileManager: driveFileManager, file: parent, files: [], normalFolderHierarchy: true)
        } else if file.parentId != 0 {
            driveFileManager.getFile(id: file.parentId) { (parent, _, error) in
                if let parent = parent {
                    self.present(driveFileManager: driveFileManager, file: parent, files: [], normalFolderHierarchy: true)
                } else {
                    UIConstants.showSnackBar(message: error?.localizedDescription ?? KDriveStrings.Localizable.errorGeneric)
                }
            }
        } else {
            UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
        }
    }

    func present(driveFileManager: DriveFileManager, file: File, files: [File], normalFolderHierarchy: Bool, fromActivities: Bool = false) {
        if file.isDirectory {
            // Show files list
            let nextVC: FileListViewController
            if driveFileManager.drive.sharedWithMe {
                nextVC = SharedWithMeViewController.instantiate(driveFileManager: driveFileManager)
            } else if file.isTrashed {
                nextVC = TrashViewController.instantiate(driveFileManager: driveFileManager)
            } else {
                nextVC = listType.instantiate(driveFileManager: driveFileManager)
            }
            nextVC.currentDirectory = file
            if file.isDisabled {
                if driveFileManager.drive.isUserAdmin {
                    floatingPanelViewController = AccessFileFloatingPanelViewController.instantiatePanel()
                    (floatingPanelViewController?.contentViewController as? AccessFileFloatingPanelViewController)?.actionHandler = { _ in
                        (self.floatingPanelViewController?.contentViewController as? AccessFileFloatingPanelViewController)?.rightButton.setLoading(true)
                        driveFileManager.apiFetcher.requireFileAccess(file: file) { (response, error) in
                            if (error != nil) {
                                UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorRightModification)
                            } else {
                                self.floatingPanelViewController?.dismiss(animated: true)
                                self.navigationController?.pushViewController(nextVC, animated: true)
                            }
                        }
                    }
                    presentFloatingPanel()
                } else {
                    floatingPanelViewController = NoAccessFloatingPanelViewController.instantiatePanel()
                    presentFloatingPanel()
                }
            } else {
                navigationController?.pushViewController(nextVC, animated: true)
            }
        } else {
            // Show file preview
            let files = files.filter { !$0.isDirectory && !$0.isTrashed }
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                let previewViewController = PreviewViewController.instantiate(files: files, index: Int(index), driveFileManager: driveFileManager, normalFolderHierarchy: normalFolderHierarchy, fromActivities: fromActivities)
                navigationController?.pushViewController(previewViewController, animated: true)
            }
            if file.isTrashed {
                UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorPreviewTrash)
            }
        }
    }

    private func presentFloatingPanel(animated: Bool = true) {
        if let floatingPanelViewController = floatingPanelViewController {
            viewController?.present(floatingPanelViewController, animated: animated)
        }
    }
}
