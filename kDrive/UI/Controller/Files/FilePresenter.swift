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

import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import SafariServices
import UIKit

@MainActor
final class FilePresenter {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var downloadQueue: DownloadQueueable

    weak var viewController: UIViewController?

    var navigationController: UINavigationController? {
        return viewController?.navigationController
    }

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    static func presentParent(of file: File, driveFileManager: DriveFileManager) {
        @InjectService var router: AppNavigable
        @InjectService var accountManager: AccountManageable

        guard let currentDriveFileManager = accountManager.currentDriveFileManager else {
            return
        }

        router.showMainViewController(
            driveFileManager: currentDriveFileManager,
            selectedIndex: MainTabBarIndex.files.rawValue
        )

        guard let rootViewController = router.getCurrentController(),
              let navigationController = rootViewController as? UINavigationController else {
            return
        }

        rootViewController.dismiss(animated: false) {
            guard let fileListViewController = navigationController.topViewController else {
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
                    let parent = try await driveFileManager.file(ProxyFile(driveId: driveFileManager.driveId, id: file.parentId))
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
                 presentationOrigin: PresentationOrigin = PresentationOrigin.fileList,
                 animated: Bool = true,
                 completion: ((Bool) -> Void)? = nil) {
        if file.isDirectory {
            presentDirectory(for: file, driveFileManager: driveFileManager, animated: animated, completion: completion)
        } else if file.isBookmark {
            downloadAndPresentBookmark(for: file, driveFileManager: driveFileManager, completion: completion)
        } else {
            presentFile(
                for: file,
                files: files,
                driveFileManager: driveFileManager,
                normalFolderHierarchy: normalFolderHierarchy,
                presentationOrigin: presentationOrigin,
                animated: animated,
                completion: completion
            )
        }
    }

    private func presentFile(for file: File,
                             files: [File],
                             driveFileManager: DriveFileManager,
                             normalFolderHierarchy: Bool,
                             presentationOrigin: PresentationOrigin,
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
                presentationOrigin: presentationOrigin
            )
            navigationController?.pushViewController(previewViewController, animated: animated)
            completion?(true)
        }
        if file.isTrashed {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorPreviewTrash)
            completion?(false)
        }
    }

    func presentDirectory(
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
            let sharedWithMeDriveFileManager = driveFileManager.instanceWith(context: .sharedWithMe)
            viewModel = SharedWithMeViewModel(driveFileManager: sharedWithMeDriveFileManager, currentDirectory: file)
        } else if case .publicShare(let proxy, let metadata) = driveFileManager.context {
            let configuration = FileListViewModel.Configuration(selectAllSupported: true,
                                                                rootTitle: nil,
                                                                emptyViewType: .emptyFolder,
                                                                supportsDrop: false,
                                                                rightBarButtons: metadata.capabilities
                                                                    .canDownload ? [.downloadAll] : [],
                                                                matomoViewPath: [
                                                                    MatomoUtils.View.menu.displayName,
                                                                    "publicShare"
                                                                ])

            viewModel = PublicShareViewModel(publicShareProxy: proxy,
                                             sortType: .nameAZ,
                                             driveFileManager: driveFileManager,
                                             currentDirectory: file,
                                             apiFetcher: PublicShareApiFetcher(),
                                             configuration: configuration)
        } else if file.isTrashed || file.deletedAt != nil {
            viewModel = TrashListViewModel(driveFileManager: driveFileManager, currentDirectory: file)
        } else {
            viewModel = ConcreteFileListViewModel(
                driveFileManager: driveFileManager,
                currentDirectory: file,
                rightBarButtons: [.search]
            )
        }

        let destinationViewController = FileListViewController(viewModel: viewModel)
        viewModel.onDismissViewController = { [weak destinationViewController] in
            destinationViewController?.dismiss(animated: true)
        }

        if file.isDisabled {
            presentNoAccessOrForceAccessPanel(
                for: file,
                driveFileManager: driveFileManager,
                accessingFileViewController: destinationViewController
            )
        } else {
            navigationController?.pushViewController(destinationViewController, animated: animated)
        }
    }

    private func presentNoAccessOrForceAccessPanel(for file: File,
                                                   driveFileManager: DriveFileManager,
                                                   accessingFileViewController: FileListViewController) {
        guard !file.isRoot && (file.visibility == .isInTeamSpaceFolder || file.visibility == .isTeamSpaceFolder) else {
            return
        }

        if driveFileManager.drive.isUserAdmin {
            presentForceAccessPanel(
                for: file,
                driveFileManager: driveFileManager,
                accessingFileViewController: accessingFileViewController
            )
        } else {
            viewController?.present(NoAccessFloatingPanelViewController.instantiatePanel(), animated: true)
        }
    }

    private func presentForceAccessPanel(for file: File,
                                         driveFileManager: DriveFileManager,
                                         accessingFileViewController: FileListViewController) {
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
                        self.navigationController?.pushViewController(accessingFileViewController, animated: true)
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

    private func downloadAndPresentBookmark(for file: File, driveFileManager: DriveFileManager, completion: ((Bool) -> Void)?) {
        if file.isMostRecentDownloaded {
            presentBookmark(for: file, completion: completion)
        } else if let publicShareProxy = driveFileManager.publicShareProxy {
            downloadQueue.addPublicShareToQueue(file: file,
                                                driveFileManager: driveFileManager,
                                                publicShareProxy: publicShareProxy,
                                                itemIdentifier: nil,
                                                onOperationCreated: nil) { error in
                self.onBookmarkDownloaded(for: file, error: error, completion: completion)
            }
        } else {
            downloadQueue.temporaryDownload(file: file, userId: accountManager.currentUserId, onOperationCreated: nil) { error in
                self.onBookmarkDownloaded(for: file, error: error, completion: completion)
            }
        }
    }

    private func onBookmarkDownloaded(for file: File, error: DriveError?, completion: ((Bool) -> Void)?) {
        Task {
            if let error {
                UIConstants.showSnackBarIfNeeded(error: error)
                completion?(false)
            } else {
                self.presentBookmark(for: file, completion: completion)
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
