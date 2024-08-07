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

import DifferenceKit
import kDriveCore
import kDriveResources
import UIKit

class RecentActivityFilesViewModel: InMemoryFileListViewModel {
    var activity: FileActivity?

    convenience init(driveFileManager: DriveFileManager, activities: [FileActivity]) {
        self.init(driveFileManager: driveFileManager)
        activity = activities.first
        addPage(files: activities.compactMap(\.file).map { $0.detached() }, fullyDownloaded: true, cursor: nil)
    }

    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        let configuration = Configuration(normalFolderHierarchy: false,
                                          showUploadingFiles: false,
                                          isMultipleSelectionEnabled: false,
                                          isRefreshControlEnabled: false,
                                          fromActivities: true,
                                          rootTitle: KDriveResourcesStrings.Localizable.fileDetailsActivitiesTitle,
                                          emptyViewType: .emptyFolder)
        super.init(
            configuration: configuration,
            driveFileManager: driveFileManager,
            currentDirectory: DriveFileManager.homeRootFile
        )
    }
}

class RecentActivityFilesViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.files }
    override class var storyboardIdentifier: String { "RecentActivityFilesViewController" }

    private var activityViewModel: RecentActivityFilesViewModel! {
        return viewModel as? RecentActivityFilesViewModel
    }

    override func setUpHeaderView(_ headerView: FilesHeaderView, isEmptyViewHidden: Bool) {
        super.setUpHeaderView(headerView, isEmptyViewHidden: isEmptyViewHidden)
        // Set up activity header
        guard let activity = activityViewModel?.activity else { return }
        headerView.activityListView.isHidden = false
        headerView.activityAvatar.image = KDriveResourcesAsset.placeholderAvatar.image

        let count = viewModel.files.count
        let isDirectory = activity.file?.isDirectory ?? false

        if let user = activity.user {
            var text = user.displayName + " "
            switch activity.action {
            case .fileCreate:
                text += isDirectory ? KDriveResourcesStrings.Localizable.fileActivityFolderCreate(count) : KDriveResourcesStrings
                    .Localizable.fileActivityFileCreate(count)
            case .fileTrash:
                text += isDirectory ? KDriveResourcesStrings.Localizable.fileActivityFolderTrash(count) : KDriveResourcesStrings
                    .Localizable.fileActivityFileTrash(count)
            case .fileUpdate:
                text += KDriveResourcesStrings.Localizable.fileActivityFileUpdate(count)
            case .commentCreate:
                text += KDriveResourcesStrings.Localizable.fileActivityCommentCreate(count)
            case .fileRestore:
                text += isDirectory ? KDriveResourcesStrings.Localizable.fileActivityFolderRestore(count) : KDriveResourcesStrings
                    .Localizable.fileActivityFileRestore(count)
            default:
                text += KDriveResourcesStrings.Localizable.fileActivityUnknown(count)
            }

            headerView.activityLabel.text = text

            user.getAvatar { image in
                headerView.activityAvatar.image = image.withRenderingMode(.alwaysOriginal)
            }
        }
    }

    override func onFilePresented(_ file: File) {
        #if !ISEXTENSION
        if file.isDirectory {
            let managedFile = driveFileManager.getManagedFile(from: file.detached())
            filePresenter.present(for: managedFile,
                                  files: viewModel.getAllFrozenFiles(),
                                  driveFileManager: viewModel.driveFileManager,
                                  normalFolderHierarchy: viewModel.configuration.normalFolderHierarchy,
                                  fromActivities: viewModel.configuration.fromActivities)
        } else {
            super.onFilePresented(file)
        }
        #endif
    }

    class func instantiate(activities: [FileActivity], driveFileManager: DriveFileManager) -> RecentActivityFilesViewController {
        return instantiate(viewModel: RecentActivityFilesViewModel(driveFileManager: driveFileManager, activities: activities))
    }

    // MARK: - Swipe action collection view data source

    override func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell,
                                 at indexPath: IndexPath) -> [SwipeCellAction]? {
        guard !viewModel.getFile(at: indexPath)!.isTrashed else {
            return nil
        }
        return super.collectionView(collectionView, actionsFor: cell, at: indexPath)
    }
}
