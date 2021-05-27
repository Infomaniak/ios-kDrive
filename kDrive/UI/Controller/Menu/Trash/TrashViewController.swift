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
import CocoaLumberjackSwift

class TrashViewController: FileListViewController {

    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "TrashViewController" }

    @IBOutlet weak var emptyTrashBarButtonItem: UIBarButtonItem!

    override func viewDidLoad() {
        // Set configuration
        configuration = Configuration(emptyViewType: .noTrash)
        filePresenter.listType = TrashViewController.self
        sortType = .newerDelete
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.trashRootFile
        }

        super.viewDidLoad()
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        if currentDirectory.id == DriveFileManager.trashRootFile.id {
            driveFileManager?.apiFetcher.getTrashedFiles(page: page, sortType: sortType) { [self] (response, error) in
                if let trashedList = response?.data {
                    completion(.success(trashedList), trashedList.count == DriveApiFetcher.itemPerPage, false)
                } else {
                    completion(.failure(error ?? DriveError.localError), false, false)
                }
            }
        } else {
            driveFileManager?.apiFetcher.getChildrenTrashedFiles(fileId: currentDirectory?.id, page: page, sortType: sortType) { [self] (response, error) in
                if let file = response?.data {
                    let children = file.children
                    completion(.success(Array(children)), children.count == DriveApiFetcher.itemPerPage, false)
                } else {
                    completion(.failure(error ?? DriveError.localError), false, false)
                }
            }
        }
    }

    override func setUpHeaderView(_ headerView: FilesHeaderView, isListEmpty: Bool) {
        super.setUpHeaderView(headerView, isListEmpty: isListEmpty)
        // Hide move button in multiple selection
        headerView.selectView.moveButton.isHidden = true
    }

    // MARK:- Actions

    @IBAction func emptyTrash(_ sender: UIBarButtonItem) {
        let alert = AlertTextViewController(title: KDriveStrings.Localizable.modalEmptyTrashTitle, message: KDriveStrings.Localizable.modalEmptyTrashDescription, action: KDriveStrings.Localizable.buttonEmpty, destructive: true, loading: true) { [unowned self] in
            let group = DispatchGroup()
            var success = false
            group.enter()
            driveFileManager.apiFetcher.deleteAllFilesDefinitely { (response, error) in
                if let error = error {
                    success = false
                    DDLogError("Error while emptying trash: \(error)")
                } else {
                    self.forceRefresh()
                    success = true
                }
                group.leave()
            }
            _ = group.wait(timeout: .now() + 5)
            DispatchQueue.main.async {
                let message = success ? KDriveStrings.Localizable.snackbarEmptyTrashConfirmation : KDriveStrings.Localizable.errorDelete
                UIConstants.showSnackBar(message: message, view: self.view)
            }
        }
        present(alert, animated: true)
    }

    // MARK: - Swipe action collection view delegate

    override func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath) {
        let file = sortedFiles[indexPath.row]
        switch action {
        case .delete:
            // TODO
            break
        default:
            break
        }
    }

    // MARK: - Swipe action collection view data source

    override func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        if configuration.fromActivities || listStyle == .grid {
            return nil
        }
        return [.delete]
    }

    // MARK: - Files header view delegate

    override func deleteButtonPressed() {
        // TODO
    }

    override func menuButtonPressed() {
        // TODO
    }

}
