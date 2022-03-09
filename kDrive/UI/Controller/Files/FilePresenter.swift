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

import kDriveCore
import kDriveResources
import SafariServices
import Sentry
import UIKit

class FilePresenter {
    weak var viewController: UIViewController?
    weak var driveFloatingPanelController: DriveFloatingPanelController?

    var listType: FileListViewController.Type = FileListViewController.self

    var navigationController: UINavigationController? {
        return viewController?.navigationController
    }

    init(viewController: UIViewController, floatingPanelViewController: DriveFloatingPanelController?) {
        self.viewController = viewController
        self.driveFloatingPanelController = floatingPanelViewController
    }

    func presentParent(of file: File, driveFileManager: DriveFileManager) {
        if var parent = file.parent {
            // Fix for weird bug: root container of shared with me is not what is expected
            if driveFileManager.drive.sharedWithMe && parent.id == DriveFileManager.constants.rootID {
                parent = DriveFileManager.sharedWithMeRootFile
            }
            present(driveFileManager: driveFileManager, file: parent, files: [], normalFolderHierarchy: true)
        } else if file.parentId != 0 {
            driveFileManager.getFile(id: file.parentId) { parent, _, error in
                if let parent = parent {
                    self.present(driveFileManager: driveFileManager, file: parent, files: [], normalFolderHierarchy: true)
                } else {
                    UIConstants.showSnackBar(message: error?.localizedDescription ?? KDriveResourcesStrings.Localizable.errorGeneric)
                }
            }
        } else {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
        }
    }

    func present(driveFileManager: DriveFileManager,
                 file: File,
                 files: [File],
                 normalFolderHierarchy: Bool,
                 fromActivities: Bool = false,
                 completion: ((Bool) -> Void)? = nil) {
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
                    driveFloatingPanelController = AccessFileFloatingPanelViewController.instantiatePanel()
                    let floatingPanelViewController = driveFloatingPanelController?.contentViewController as? AccessFileFloatingPanelViewController
                    floatingPanelViewController?.actionHandler = { [weak self] _ in
                        floatingPanelViewController?.rightButton.setLoading(true)
                        driveFileManager.apiFetcher.requireFileAccess(file: file) { _, error in
                            if error != nil {
                                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorRightModification)
                            } else {
                                self?.driveFloatingPanelController?.dismiss(animated: true)
                                self?.navigationController?.pushViewController(nextVC, animated: true)
                            }
                        }
                    }
                    presentFloatingPanel()
                } else {
                    driveFloatingPanelController = NoAccessFloatingPanelViewController.instantiatePanel()
                    presentFloatingPanel()
                }
            } else {
                navigationController?.pushViewController(nextVC, animated: true)
            }
            completion?(true)
        } else if file.isBookmark {
            // Open bookmark URL
            if file.isMostRecentDownloaded {
                presentBookmark(for: file, completion: completion)
            } else {
                // Download file
                DownloadQueue.instance.temporaryDownload(file: file) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            UIConstants.showSnackBar(message: error.localizedDescription)
                            completion?(false)
                        } else {
                            self.presentBookmark(for: file, completion: completion)
                        }
                    }
                }
            }
        } else {
            // Show file preview
            let files = files.filter { !$0.isDirectory && !$0.isTrashed }
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                let previewViewController = PreviewViewController.instantiate(files: files, index: Int(index), driveFileManager: driveFileManager, normalFolderHierarchy: normalFolderHierarchy, fromActivities: fromActivities)
                navigationController?.pushViewController(previewViewController, animated: true)
                completion?(true)
            }
            if file.isTrashed {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorPreviewTrash)
                completion?(false)
            }
        }
    }

    private func presentFloatingPanel(animated: Bool = true) {
        if let driveFloatingPanelController = driveFloatingPanelController {
            viewController?.present(driveFloatingPanelController, animated: animated)
        }
    }

    private func presentBookmark(for file: File, animated: Bool = true, completion: ((Bool) -> Void)? = nil) {
        if let url = file.getBookmarkURL() {
            if url.scheme == "http" || url.scheme == "https" {
                let safariViewController = SFSafariViewController(url: url)
                viewController?.present(safariViewController, animated: animated)
                completion?(true)
            } else {
                SentrySDK.capture(message: "Tried to present unsupported scheme") { scope in
                    scope.setContext(value: ["URL": url.absoluteString], key: "Details")
                }
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGetBookmarkURL)
                completion?(false)
            }
        } else {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGetBookmarkURL)
            completion?(false)
        }
    }
}
