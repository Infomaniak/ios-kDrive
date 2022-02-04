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

import InfomaniakCore
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

protocol SelectFolderDelegate: AnyObject {
    func didSelectFolder(_ folder: File)
}

class SelectFolderViewModel: ConcreteFileListViewModel {
    required init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        let configuration = FileListViewModel.Configuration(showUploadingFiles: false, isMultipleSelectionEnabled: false, rootTitle: KDriveResourcesStrings.Localizable.selectFolderTitle, emptyViewType: .emptyFolder)

        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        self.files = AnyRealmCollection(self.currentDirectory.children)
    }
}

class SelectFolderViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.saveFile }
    override class var storyboardIdentifier: String { "SelectFolderViewController" }

    @IBOutlet weak var selectFolderButton: UIButton!
    @IBOutlet weak var addFolderButton: UIBarButtonItem!

    var disabledDirectoriesSelection = [Int]()
    var fileToMove: Int?
    weak var delegate: SelectFolderDelegate?
    var selectHandler: ((File) -> Void)?

    var isModal: Bool {
        let presentingIsModal = presentingViewController != nil
        let presentingIsNavigation = navigationController?.presentingViewController?.presentedViewController == navigationController
        let presentingIsTabBar = tabBarController?.presentingViewController is UITabBarController

        return presentingIsModal || presentingIsNavigation || presentingIsTabBar
    }

    override func viewDidLoad() {
        // Set configuration
        super.viewDidLoad()

        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listFloatingButtonPaddingBottom, right: 0)
        setUpDirectory()
    }

    private func setUpDirectory() {
        addFolderButton.isEnabled = currentDirectory.capabilities.canCreateDirectory
        addFolderButton.accessibilityLabel = KDriveResourcesStrings.Localizable.createFolderTitle
        selectFolderButton.isEnabled = !disabledDirectoriesSelection.contains(currentDirectory.id) && (currentDirectory.capabilities.canMoveInto || currentDirectory.capabilities.canCreateFile)
        if currentDirectory.id == DriveFileManager.constants.rootID {
            // Root directory: set back button if the view controller is presented modally
            let viewControllersCount = navigationController?.viewControllers.count ?? 0
            if isModal && viewControllersCount < 2 {
                navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
                navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
            }
        }
    }

    static func instantiateInNavigationController(driveFileManager: DriveFileManager, startDirectory: File? = nil, fileToMove: Int? = nil, disabledDirectoriesSelection: [File] = [], delegate: SelectFolderDelegate? = nil, selectHandler: ((File) -> Void)? = nil) -> TitleSizeAdjustingNavigationController {
        var viewControllers = [SelectFolderViewController]()
        let disabledDirectoriesSelection = disabledDirectoriesSelection.map(\.id)
        if startDirectory == nil || startDirectory?.isRoot == true {
            let selectFolderViewController = instantiate(viewModel: SelectFolderViewModel(driveFileManager: driveFileManager, currentDirectory: nil))
            selectFolderViewController.disabledDirectoriesSelection = disabledDirectoriesSelection
            selectFolderViewController.fileToMove = fileToMove
            selectFolderViewController.delegate = delegate
            selectFolderViewController.selectHandler = selectHandler
            selectFolderViewController.navigationItem.hideBackButtonText()
            viewControllers.append(selectFolderViewController)
        } else {
            var directory = startDirectory
            while directory != nil {
                let selectFolderViewController = instantiate(viewModel: SelectFolderViewModel(driveFileManager: driveFileManager, currentDirectory: directory))
                selectFolderViewController.disabledDirectoriesSelection = disabledDirectoriesSelection
                selectFolderViewController.fileToMove = fileToMove
                selectFolderViewController.currentDirectory = directory
                selectFolderViewController.delegate = delegate
                selectFolderViewController.selectHandler = selectHandler
                selectFolderViewController.navigationItem.hideBackButtonText()
                viewControllers.append(selectFolderViewController)
                directory = directory?.parent
            }
        }
        let navigationController = TitleSizeAdjustingNavigationController()
        navigationController.setViewControllers(viewControllers.reversed(), animated: false)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    // MARK: - Actions

    @objc func closeButtonPressed() {
        dismiss(animated: true)
    }

    @IBAction func selectButtonPressed(_ sender: UIButton) {
        delegate?.didSelectFolder(currentDirectory)
        selectHandler?(currentDirectory)
        // We are only selecting files we can dismiss
        if navigationController?.viewControllers.first is SelectFolderViewController {
            navigationController?.dismiss(animated: true)
        } else {
            // We are creating file, go back to file name
            navigationController?.popToRootViewController(animated: true)
        }
    }

    @IBAction func addFolderButtonPressed(_ sender: UIBarButtonItem) {
        let newFolderViewController = NewFolderTypeTableViewController.instantiateInNavigationController(parentDirectory: currentDirectory, driveFileManager: driveFileManager)
        navigationController?.present(newFolderViewController, animated: true)
    }

    // MARK: - Collection view data source

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let file = viewModel.getFile(at: indexPath.item)!
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! FileCollectionViewCell
        cell.setEnabled(file.isDirectory && file.id != fileToMove)
        cell.moreButton.isHidden = true
        return cell
    }

    // MARK: - Collection view delegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedFile = viewModel.getFile(at: indexPath.item)!
        if selectedFile.isDirectory {
            let nextVC = SelectFolderViewController.instantiate(viewModel: SelectFolderViewModel(driveFileManager: driveFileManager, currentDirectory: selectedFile))
            nextVC.disabledDirectoriesSelection = disabledDirectoriesSelection
            nextVC.fileToMove = fileToMove
            nextVC.currentDirectory = selectedFile
            nextVC.delegate = delegate
            nextVC.selectHandler = selectHandler
            navigationController?.pushViewController(nextVC, animated: true)
        }
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(disabledDirectoriesSelection, forKey: "DisabledDirectories")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        disabledDirectoriesSelection = coder.decodeObject(forKey: "DisabledDirectories") as? [Int] ?? []
        setUpDirectory()
    }
}
