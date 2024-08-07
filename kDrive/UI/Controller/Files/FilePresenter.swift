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
import kDriveResources
import SafariServices
import UIKit

@MainActor
final class FilePresenter {
    @LazyInjectService var accountManager: AccountManageable

    weak var viewController: UIViewController?

    var navigationController: UINavigationController? {
        return viewController?.navigationController
    }

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    class func presentParent(of file: File, driveFileManager: DriveFileManager, viewController: UIViewController) {
        guard let rootViewController = viewController.view.window?.rootViewController as? MainTabViewController else {
            return
        }

        viewController.navigationController?.popToRootViewController(animated: false)

        rootViewController.dismiss(animated: false) {
            rootViewController.selectedIndex = MainTabBarIndex.files.rawValue

            guard let navigationController = rootViewController.selectedViewController as? UINavigationController else {
                return
            }

            navigationController.popToRootViewController(animated: false)

            guard let fileListViewController = navigationController.topViewController as? FileListViewController else {
                return
            }

            let filePresenter = FilePresenter(viewController: fileListViewController)
            filePresenter.presentParent(of: file, driveFileManager: driveFileManager, animated: false)
        }
    }

    func presentParent(of file: File, driveFileManager: DriveFileManager, animated: Bool = true) {
        if let parent = file.parent {
            present(for: parent, files: [], driveFileManager: driveFileManager, normalFolderHierarchy: true, animated: animated)
        } else if file.parentId != 0 {
            Task {
                do {
                    let parent = try await driveFileManager.file(id: file.parentId)
                    present(for: parent,
                            files: [],
                            driveFileManager: driveFileManager,
                            normalFolderHierarchy: true,
                            animated: animated)
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
            }
        } else {
            UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
        }
    }

    func present(for file: File,
                 files: [File],
                 driveFileManager: DriveFileManager,
                 normalFolderHierarchy: Bool,
                 fromActivities: Bool = false,
                 animated: Bool = true,
                 completion: ((Bool) -> Void)? = nil) {
        if file.isDirectory {
            presentDirectory(for: file, driveFileManager: driveFileManager, animated: animated, completion: completion)
        } else if file.isBookmark {
            downloadAndPresentBookmark(for: file, completion: completion)
        } else {
            presentFile(
                for: file,
                files: files,
                driveFileManager: driveFileManager,
                normalFolderHierarchy: normalFolderHierarchy,
                fromActivities: fromActivities,
                animated: animated,
                completion: completion
            )
        }
    }

    private func presentFile(for file: File,
                             files: [File],
                             driveFileManager: DriveFileManager,
                             normalFolderHierarchy: Bool,
                             fromActivities: Bool,
                             animated: Bool,
                             completion: ((Bool) -> Void)?) {
        // Show file preview
        let files = files.filter { !$0.isDirectory && !$0.isTrashed }
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            let previewViewController = PreviewViewController.instantiate(
                files: files,
                index: Int(index),
                driveFileManager: driveFileManager,
                normalFolderHierarchy: normalFolderHierarchy,
                fromActivities: fromActivities
            )
            navigationController?.pushViewController(previewViewController, animated: animated)
            completion?(true)
        }
        if file.isTrashed {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorPreviewTrash)
            completion?(false)
        }
    }

    public func presentDirectory(
        for file: File,
        driveFileManager: DriveFileManager,
        animated: Bool,
        completion: ((Bool) -> Void)?
    ) {
        defer {
            completion?(true)
        }

        let viewModel: FileListViewModel
        if driveFileManager.drive.sharedWithMe {
            viewModel = SharedWithMeViewModel(driveFileManager: driveFileManager, currentDirectory: file)
        } else if file.isTrashed || file.deletedAt != nil {
            viewModel = TrashListViewModel(driveFileManager: driveFileManager, currentDirectory: file)
        } else {
            viewModel = ConcreteFileListViewModel(driveFileManager: driveFileManager, currentDirectory: file)
        }

        let nextVC = FileListViewController(viewModel: viewModel)
        guard file.isDisabled else {
            navigationController?.pushViewController(nextVC, animated: animated)
            return
        }

        guard driveFileManager.drive.isUserAdmin else {
            viewController?.present(NoAccessFloatingPanelViewController.instantiatePanel(), animated: true)
            return
        }

        let accessFileDriveFloatingPanelController = AccessFileFloatingPanelViewController.instantiatePanel()
        let floatingPanelViewController = accessFileDriveFloatingPanelController
            .contentViewController as? AccessFileFloatingPanelViewController
        floatingPanelViewController?.actionHandler = { [weak self] _ in
            guard let self else { return }
            floatingPanelViewController?.rightButton.setLoading(true)
            Task { [proxyFile = file.proxify()] in
                do {
                    let response = try await driveFileManager.apiFetcher.forceAccess(to: proxyFile)
                    if response {
                        accessFileDriveFloatingPanelController.dismiss(animated: true)
                        self.navigationController?.pushViewController(nextVC, animated: true)
                    } else {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorRightModification)
                    }
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
            }
        }

        viewController?.present(accessFileDriveFloatingPanelController, animated: true)
    }

    private func downloadAndPresentBookmark(for file: File, completion: ((Bool) -> Void)?) {
        // Open bookmark URL
        if file.isMostRecentDownloaded {
            presentBookmark(for: file, completion: completion)
        } else {
            // Download file
            DownloadQueue.instance.temporaryDownload(file: file, userId: accountManager.currentUserId) { error in
                Task {
                    if let error {
                        UIConstants.showSnackBarIfNeeded(error: error)
                        completion?(false)
                    } else {
                        self.presentBookmark(for: file, completion: completion)
                    }
                }
            }
        }
    }

    private func presentBookmark(for file: File, animated: Bool = true, completion: ((Bool) -> Void)?) {
        if let url = file.getBookmarkURL() {
            if url.scheme == "http" || url.scheme == "https" {
                let safariViewController = SFSafariViewController(url: url)
                viewController?.present(safariViewController, animated: animated)
                completion?(true)
            } else {
                let message = "Tried to present unsupported scheme"
                let metadata = ["Scheme": url.scheme ?? "No scheme"]
                SentryDebug.capture(message: message, context: metadata, contextKey: "Details")

                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGetBookmarkURL)
                completion?(false)
            }
        } else {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGetBookmarkURL)
            completion?(false)
        }
    }
}
