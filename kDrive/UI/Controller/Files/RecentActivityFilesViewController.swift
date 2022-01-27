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
import UIKit

class RecentActivityFilesViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.files }
    override class var storyboardIdentifier: String { "RecentActivityFilesViewController" }

    private var activity: FileActivity?
    private var activityFiles: [File] = []

    override func viewDidLoad() {
        // Set configuration
        configuration = Configuration(normalFolderHierarchy: false, showUploadingFiles: false, isMultipleSelectionEnabled: false, isRefreshControlEnabled: false, fromActivities: true, rootTitle: KDriveResourcesStrings.Localizable.fileDetailsActivitiesTitle, emptyViewType: .emptyFolder)

        super.viewDidLoad()
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        DispatchQueue.main.async {
            completion(.success(self.sortFiles(self.activityFiles)), false, true)
        }
    }

    override func getNewChanges() {
        // No update needed
    }

    override func setUpHeaderView(_ headerView: FilesHeaderView, isListEmpty: Bool) {
        super.setUpHeaderView(headerView, isListEmpty: isListEmpty)
        // Set up activity header
        guard let activity = activity else { return }
        headerView.activityListView.isHidden = false
        headerView.activityAvatar.image = KDriveResourcesAsset.placeholderAvatar.image

        let count = activityFiles.count
        let isDirectory = activity.file?.isDirectory ?? false

        if let user = activity.user {
            var text = user.displayName + " "
            switch activity.action {
            case .fileCreate:
                text += isDirectory ? KDriveResourcesStrings.Localizable.fileActivityFolderCreate(count) : KDriveResourcesStrings.Localizable.fileActivityFileCreate(count)
            case .fileTrash:
                text += isDirectory ? KDriveResourcesStrings.Localizable.fileActivityFolderTrash(count) : KDriveResourcesStrings.Localizable.fileActivityFileTrash(count)
            case .fileUpdate:
                text += KDriveResourcesStrings.Localizable.fileActivityFileUpdate(count)
            case .commentCreate:
                text += KDriveResourcesStrings.Localizable.fileActivityCommentCreate(count)
            case .fileRestore:
                text += isDirectory ? KDriveResourcesStrings.Localizable.fileActivityFolderRestore(count) : KDriveResourcesStrings.Localizable.fileActivityFileRestore(count)
            default:
                text += KDriveResourcesStrings.Localizable.fileActivityUnknown(count)
            }

            headerView.activityLabel.text = text

            user.getAvatar { image in
                headerView.activityAvatar.image = image.withRenderingMode(.alwaysOriginal)
            }
        }
    }

    class func instantiate(activities: [FileActivity], driveFileManager: DriveFileManager) -> RecentActivityFilesViewController {
        let viewController = instantiate(driveFileManager: driveFileManager)
        viewController.activityFiles = activities.compactMap(\.file)
        viewController.activity = activities.first
        return viewController
    }

    // MARK: - Private methods

    private func sortFiles(_ files: [File]) -> [File] {
        return files.sorted { firstFile, secondFile -> Bool in
            switch sortType {
            case .nameAZ:
                return firstFile.name.lowercased() < secondFile.name.lowercased()
            case .nameZA:
                return firstFile.name.lowercased() > secondFile.name.lowercased()
            case .older:
                return firstFile.lastModifiedAt < secondFile.lastModifiedAt
            case .newer:
                return firstFile.lastModifiedAt > secondFile.lastModifiedAt
            case .biggest:
                return firstFile.size ?? 0 > secondFile.size ?? 0
            case .smallest:
                return firstFile.size ?? 0 < secondFile.size ?? 0
            default:
                return true
            }
        }
    }

    // MARK: - Swipe action collection view data source

    override func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        if sortedFiles[indexPath.row].isTrashed {
            return nil
        }
        return super.collectionView(collectionView, actionsFor: cell, at: indexPath)
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(activity?.id ?? 0, forKey: "ActivityId")
        coder.encode(activityFiles.map(\.id), forKey: "Files")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let activityId = coder.decodeInteger(forKey: "ActivityId")
        let activityFileIds = coder.decodeObject(forKey: "Files") as? [Int] ?? []
        navigationItem.title = KDriveResourcesStrings.Localizable.fileDetailsActivitiesTitle
        if driveFileManager != nil {
            let realm = driveFileManager.getRealm()
            activity = realm.object(ofType: FileActivity.self, forPrimaryKey: activityId)
            activityFiles = activityFileIds.compactMap { driveFileManager.getCachedFile(id: $0, using: realm) }
            forceRefresh()
        }
    }
}
