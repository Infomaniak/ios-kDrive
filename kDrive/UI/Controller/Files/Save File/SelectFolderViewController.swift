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
import InfomaniakCore

protocol SelectFolderDelegate: AnyObject {
    func didSelectFolder(_ folder: File)
}

class SelectFolderViewController: FileListCollectionViewController {

    @IBOutlet weak var selectFolderButton: UIButton!
    @IBOutlet weak var addFolderButton: UIBarButtonItem!

    override var isMultipleSelectionEnabled: Bool {
        return false
    }

    override var showUploadingFiles: Bool {
        return false
    }

    var disabledDirectoriesSelection = [File]()
    var fileToMove: Int? = nil
    weak var delegate: SelectFolderDelegate?
    var selectHandler: ((File) -> (Void))?

    var isModal: Bool {
        let presentingIsModal = presentingViewController != nil
        let presentingIsNavigation = navigationController?.presentingViewController?.presentedViewController == navigationController
        let presentingIsTabBar = tabBarController?.presentingViewController is UITabBarController

        return presentingIsModal || presentingIsNavigation || presentingIsTabBar
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listFloatingButtonPaddingBottom, right: 0)
        setUpDirectory()
    }

    private func setUpDirectory() {
        addFolderButton.isEnabled = currentDirectory.rights?.createNewFolder.value ?? false
        addFolderButton.accessibilityLabel = KDriveStrings.Localizable.createFolderTitle
        selectFolderButton.isEnabled = !(disabledDirectoriesSelection.map(\.id).contains(currentDirectory.id)) && (currentDirectory.rights?.moveInto.value ?? false || currentDirectory.rights?.createNewFile.value ?? false)
        if currentDirectory.id == DriveFileManager.constants.rootID {
            // Root directory
            navigationItem.title = KDriveStrings.Localizable.selectFolderTitle
            // Set back button if the view controller is presented modally
            let nbViewControllers = navigationController?.viewControllers.count ?? 0
            if isModal && nbViewControllers < 2 {
                navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(close))
                navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveStrings.Localizable.buttonClose
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let file = sortedChildren[indexPath.row]
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! FileCollectionViewCell
        cell.setEnabled(file.isDirectory && file.id != fileToMove)
        cell.moreButton.isHidden = true
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedFile = sortedChildren[indexPath.row]
        if selectedFile.isDirectory {
            let nextVC = SelectFolderViewController.instantiate()
            nextVC.disabledDirectoriesSelection = disabledDirectoriesSelection
            nextVC.fileToMove = fileToMove
            nextVC.driveFileManager = driveFileManager
            nextVC.currentDirectory = selectedFile
            nextVC.delegate = delegate
            nextVC.selectHandler = selectHandler
            nextVC.sortType = sortType
            navigationController?.pushViewController(nextVC, animated: true)
        }
    }

    @objc func close() {
        dismiss(animated: true)
    }

    @IBAction func selectButtonPressed(_ sender: UIButton) {
        delegate?.didSelectFolder(currentDirectory)
        selectHandler?(currentDirectory)
        //We are only selecting files we can dismiss
        if navigationController?.viewControllers.first is SelectFolderViewController {
            navigationController?.dismiss(animated: true)
        } else {
            //We are creating file, go back to file name
            navigationController?.popToRootViewController(animated: true)
        }
    }

    @IBAction func addFolderButtonPressed(_ sender: UIBarButtonItem) {
        let newFolderViewController = NewFolderTypeTableViewController.instantiateInNavigationController(parentDirectory: currentDirectory, driveFileManager: driveFileManager)
        navigationController?.present(newFolderViewController, animated: true)
    }

    class func instantiateInNavigationController(driveFileManager: DriveFileManager) -> TitleSizeAdjustingNavigationController {
        let selectFolderViewController = instantiate()
        selectFolderViewController.driveFileManager = driveFileManager
        let navigationController = TitleSizeAdjustingNavigationController(rootViewController: selectFolderViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    override class func instantiate() -> SelectFolderViewController {
        return UIStoryboard(name: "SaveFile", bundle: nil).instantiateViewController(withIdentifier: "SelectFolderViewController") as! SelectFolderViewController
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(disabledDirectoriesSelection.map(\.id), forKey: "DisabledDirectories")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let disabledDirectoriesIds = coder.decodeObject(forKey: "DisabledDirectories") as? [Int] ?? []
        if driveFileManager != nil {
            let realm = driveFileManager.getRealm()
            disabledDirectoriesSelection = disabledDirectoriesIds.compactMap { driveFileManager.getCachedFile(id: $0, using: realm) }
        }
        setUpDirectory()
    }
}
