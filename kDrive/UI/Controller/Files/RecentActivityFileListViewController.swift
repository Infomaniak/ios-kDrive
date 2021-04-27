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

class RecentActivityFileListViewController: FileListCollectionViewController {

    override var normalFolderHierarchy: Bool {
        return false
    }
    override var isMultipleSelectionEnabled: Bool {
        return false
    }

    var activity: FileActivity?
    var activityFiles: [File]!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = KDriveStrings.Localizable.fileDetailsActivitiesTitle
        navigationItem.largeTitleDisplayMode = .always

        fromActivities = true
    }

    override func getFileActivities(directory: File) {
    }

    override func fetchNextPage(forceRefresh: Bool = false) {
        sortedChildren = sortFiles(files: activityFiles)
    }
    
    private func sortFiles(files: [File]) -> [File] {
        var sortedList = files
        sortedList.sort { (firstFile, secondFile) -> Bool in
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
                return firstFile.size > secondFile.size
            case .smallest:
                return firstFile.size < secondFile.size
            default:
                return true
            }
        }
        return sortedList
    }

    override func addRefreshControl() {
    }

    class func instantiate(activities: [FileActivity]) -> RecentActivityFileListViewController {
        let vc = UIStoryboard(name: "Files", bundle: nil).instantiateViewController(withIdentifier: "RecentActivityFileListViewController") as! RecentActivityFileListViewController
        vc.activityFiles = activities.compactMap(\.file)
        vc.sortedChildren = activities.compactMap(\.file)
        vc.sortedChildren.first?.isFirstInCollection = true
        vc.sortedChildren.last?.isLastInCollection = true
        vc.activity = activities.first
        return vc
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = super.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
        (headerView as? FilesHeaderView)?.activityListView.isHidden = false

        setupHeaderView(headerView: headerView as? FilesHeaderView)

        return headerView
    }

    private func setupHeaderView(headerView: FilesHeaderView?) {
        guard let activity = activity else { return }
        let count = sortedChildren.count
        let isDirectory = activity.file?.isDirectory ?? false
        headerView?.activityAvatar.image = KDriveAsset.placeholderAvatar.image

        if let user = activity.user {
            var text = user.displayName + " "
            switch activity.action {
            case .fileCreate:
                text += isDirectory ? KDriveStrings.Localizable.fileActivityFolderCreate(count) : KDriveStrings.Localizable.fileActivityFileCreate(count)
            case .fileTrash:
                text += isDirectory ? KDriveStrings.Localizable.fileActivityFolderTrash(count) : KDriveStrings.Localizable.fileActivityFileTrash(count)
            case .fileUpdate:
                text += KDriveStrings.Localizable.fileActivityFileUpdate(count)
            case .commentCreate:
                text += KDriveStrings.Localizable.fileActivityCommentCreate(count)
            case .fileRestore:
                text += isDirectory ? KDriveStrings.Localizable.fileActivityFolderRestore(count) : KDriveStrings.Localizable.fileActivityFileRestore(count)
            default:
                text += KDriveStrings.Localizable.fileActivityUnknown(count)
            }

            headerView?.activityLabel.text = text

            user.getAvatar { (image) in
                headerView?.activityAvatar.image = image.withRenderingMode(.alwaysOriginal)
            }
        }
    }

    override func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        if sortedChildren[indexPath.row].isTrashed {
            return nil
        }
        return super.collectionView(collectionView, actionsFor: cell, at: indexPath)
    }
}
