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
import DifferenceKit
import RealmSwift
import InfomaniakCore
import CocoaLumberjackSwift

class TrashCollectionViewController: FileListCollectionViewController {
    @IBOutlet weak var emptyTrashBarButtonItem: UIBarButtonItem!

    private var reachedEnd = false
    var selectFolderViewController: TitleSizeAdjustingNavigationController!

    var currentTrashedFiles: [File]?

    override func viewDidLoad() {
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.trashRootFile
        }
        sortType = .newerDelete

        super.viewDidLoad()

        if currentDirectory.id == DriveFileManager.trashRootFile.id {
            navigationItem.title = KDriveStrings.Localizable.trashTitle
        }
    }

    override func fetchNextPage(forceRefresh: Bool = false) {
        currentPage += 1
        startLoading()

        if currentDirectory.id == DriveFileManager.trashRootFile.id {
            driveFileManager.apiFetcher.getTrashedFiles(page: currentPage, sortType: sortType) { [self] (response, error) in
                self.isLoading = false
                collectionView.refreshControl?.endRefreshing()
                if let trashedList = response?.data {
                    getNewChildren(newChildren: trashedList)
                }

                if !currentDirectory.fullyDownloaded && sortedChildren.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
                    showEmptyView(.noNetwork, children: sortedChildren, showButton: true)
                }
            }
        } else {
            driveFileManager.apiFetcher.getChildrenTrashedFiles(fileId: currentDirectory?.id, page: currentPage, sortType: sortType) { [self] (response, error) in
                self.isLoading = false
                collectionView.refreshControl?.endRefreshing()

                if let file = response?.data {
                    var children = [File]()
                    children.append(contentsOf: file.children)
                    getNewChildren(newChildren: children)
                }

                if !currentDirectory.fullyDownloaded && sortedChildren.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
                    showEmptyView(.noNetwork, children: sortedChildren, showButton: true)
                }
            }
        }
    }

    private func getNewChildren(newChildren: [File] = [], deletedChild: File? = nil) {
        sortedChildren.first?.isFirstInCollection = false
        sortedChildren.last?.isLastInCollection = false
        var newSortedChildren = sortedChildren.map { File(value: $0) } + newChildren

        if deletedChild != nil {
            newSortedChildren = newSortedChildren.filter { $0.id != deletedChild!.id }
        }

        newSortedChildren.first?.isFirstInCollection = true
        newSortedChildren.last?.isLastInCollection = true

        let changeSet = getChangesetFor(newChildren: newSortedChildren)
        collectionView.reload(using: changeSet) { newChildren in
            sortedChildren = newChildren
        }
        if newChildren.count < DriveApiFetcher.itemPerPage {
            reachedEnd = true
        }

        showEmptyView(.noTrash, children: newSortedChildren)
    }

    override func forceRefresh() {
        currentPage = 0
        reachedEnd = false
        sortedChildren = []
        collectionView.reloadData()
        fetchNextPage(forceRefresh: true)
        if currentDirectory.id == DriveFileManager.trashRootFile.id {
            navigationItem.title = KDriveStrings.Localizable.trashTitle
        }
    }

    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        super.collectionView(collectionView, willDisplay: cell, forItemAt: indexPath)
        if indexPath.row >= currentPage * DriveApiFetcher.itemPerPage - 1 && indexPath.row >= sortedChildren.count - 1 && !reachedEnd {
            fetchNextPage()
        }
    }

    override func showEmptyView(_ type: EmptyTableView.EmptyTableViewType, children: [File], showButton: Bool = false) {
        if children.isEmpty {
            let background = EmptyTableView.instantiate(type: type, button: showButton)
            background.actionHandler = { sender in
                self.forceRefresh()
            }
            collectionView.backgroundView = background
            headerView?.sortView.isHidden = true
            emptyTrashBarButtonItem.isEnabled = false
        } else {
            collectionView.backgroundView = nil
            headerView?.sortView.isHidden = false
            emptyTrashBarButtonItem.isEnabled = true
        }
    }

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

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if selectionMode {
            selectChild(at: indexPath)
            return
        }

        let file = sortedChildren[indexPath.row]
        if file.isDirectory {
            let trashCV = TrashCollectionViewController.instantiate()
            trashCV.currentDirectory = file
            self.navigationController?.pushViewController(trashCV, animated: true)
        } else {
            showFloatingPanel(files: [file])
        }
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = super.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
        (headerView as? FilesHeaderView)?.selectView.moveButton.isHidden = true

        return headerView
    }

    // MARK: - SwipeActionCollectionViewDelegate

    override func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath) {
        let file = sortedChildren[indexPath.row]
        switch action.identifier {
        case UIConstants.swipeActionDeleteIdentifier:
            deleteActionSelected(files: [file])
        default:
            break
        }
    }

    // MARK: - SwipeActionCollectionViewDatasource

    override func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        switch listStyle {
        case .list:
            return [
                SwipeCellAction(identifier: "delete", title: KDriveStrings.Localizable.buttonDelete, backgroundColor: KDriveAsset.binColor.color, icon: KDriveAsset.delete.image)
            ]
        case .grid:
            return nil
        }
    }

    // MARK: - File cell delegate

    override func didTapMoreButton(_ cell: FileCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }

        let file = sortedChildren[indexPath.row]
        showFloatingPanel(files: [file])
    }

    // MARK: - State restoration

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        if currentDirectory.id == DriveFileManager.trashRootFile.id {
            navigationItem.title = KDriveStrings.Localizable.trashTitle
        }
    }

    private func deleteActionSelected(files: [File]) {
        let message: NSMutableAttributedString
        if files.count == 1 {
            message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalDeleteDescription(files[0].name), boldText: files[0].name)
        } else {
            message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalDeleteDescriptionPlural(files.count))
        }
        let alert = AlertTextViewController(title: KDriveStrings.Localizable.trashActionDelete, message: message, action: KDriveStrings.Localizable.buttonDelete, destructive: true, loading: true) {
            let group = DispatchGroup()
            var success = true
            for file in files {
                group.enter()
                self.driveFileManager.apiFetcher.deleteFileDefinitely(file: file) { (response, error) in
                    file.signalChanges()
                    if let error = error {
                        success = false
                        DDLogError("Error while deleting file: \(error)")
                    } else {
                        self.getNewChildren(deletedChild: file)
                    }
                    group.leave()
                }
            }
            let result = group.wait(timeout: .now() + 5)
            if result == .timedOut {
                success = false
            }
            DispatchQueue.main.async {
                let message: String
                if success {
                    if files.count == 1 {
                        message = KDriveStrings.Localizable.snackbarDeleteConfirmation(files[0].name)
                    } else {
                        message = KDriveStrings.Localizable.snackbarDeleteConfirmationPlural(files.count)
                    }
                } else {
                    message = KDriveStrings.Localizable.errorDelete
                }
                UIConstants.showSnackBar(message: message, view: self.view)
                self.selectionMode = false
            }
        }
        present(alert, animated: true)
    }

    private func showFloatingPanel(files: [File]) {
        let floatingPanelViewController = DriveFloatingPanelController()
        let trashFloatingPanelTableViewController = TrashFloatingPanelTableViewController()
        floatingPanelViewController.isRemovalInteractionEnabled = true
        trashFloatingPanelTableViewController.delegate = self
        trashFloatingPanelTableViewController.trashedFiles = files
        floatingPanelViewController.layout = PlusButtonFloatingPanelLayout(height: 200)

        floatingPanelViewController.set(contentViewController: trashFloatingPanelTableViewController)
        self.present(floatingPanelViewController, animated: true)
    }

    override class func instantiate() -> TrashCollectionViewController {
        return UIStoryboard(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "TrashCollectionViewController") as! TrashCollectionViewController
    }

    override func deleteButtonPressed() {
        deleteActionSelected(files: selectedItems)
    }

    override func menuButtonPressed() {
        showFloatingPanel(files: selectedItems)
    }
}

// MARK: - TrashOptionsDelegate

extension TrashCollectionViewController: TrashOptionsDelegate {

    func didClickOnTrashOption(option: TrashOption, files: [File]) {
        switch option {
        case .restoreIn:
            currentTrashedFiles = files
            selectFolderViewController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager)
            selectFolderViewController.modalPresentationStyle = .fullScreen
            if let selectFolderVC = selectFolderViewController.viewControllers.first as? SelectFolderViewController {
                selectFolderVC.delegate = self
            }
            present(selectFolderViewController, animated: true)
        case .restore:
            let group = DispatchGroup()
            for file in files {
                group.enter()
                driveFileManager.apiFetcher.restoreTrashedFile(file: file) { [self] (response, error) in
                    // TODO: Find parent to signal changes
                    file.signalChanges()
                    if error == nil {
                        getNewChildren(deletedChild: file)
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.trashedFileRestoreFileToOriginalPlaceSuccess(file.name))
                    } else {
                        UIConstants.showSnackBar(message: error?.localizedDescription ?? KDriveStrings.Localizable.errorRestore)
                    }
                    group.leave()
                }
            }
            group.notify(queue: DispatchQueue.main) {
                self.selectionMode = false
            }
        case .delete:
            deleteActionSelected(files: files)
        }
    }
}

// MARK: - SelectFolderDelegate

extension TrashCollectionViewController: SelectFolderDelegate {
    func didSelectFolder(_ folder: File) {
        let group = DispatchGroup()
        for file in currentTrashedFiles ?? [] {
            group.enter()
            driveFileManager.apiFetcher.restoreTrashedFile(file: file, in: folder.id) { [self] (response, error) in
                folder.signalChanges()
                if error == nil {
                    getNewChildren(deletedChild: file)
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.trashedFileRestoreFileInSuccess(file.name, folder.name), view: self.view)
                } else {
                    UIConstants.showSnackBar(message: error?.localizedDescription ?? KDriveStrings.Localizable.errorRestore)
                }
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.main) {
            self.selectFolderViewController.dismiss(animated: true)
            self.selectionMode = false
        }
    }
}
