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

import CocoaLumberjackSwift
import InfomaniakCore
import kDriveCore
import kDriveResources
import UIKit

class TrashViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "TrashViewController" }

    override func getViewModel() -> FileListViewModel {
        return TrashListViewModel(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
    }

    // MARK: - Private methods

    // MARK: - Swipe action collection view delegate

    override func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath) {
        let file = viewModel.getFile(at: indexPath.item)!
        switch action {
        case .delete:
            (viewModel as? TrashListViewModel)?.didClickOnTrashOption(option: .delete, files: [file])
        default:
            break
        }
    }

    // MARK: - Swipe action collection view data source

    override func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        if viewModel.configuration.fromActivities || viewModel.listStyle == .grid {
            return nil
        }
        return [.delete]
    }
}
