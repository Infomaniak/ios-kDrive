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
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

protocol SelectFolderDelegate: AnyObject {
    func didSelectFolder(_ folder: File)
}

class SelectFolderViewModel: ConcreteFileListViewModel {
    required init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        let currentDirectory = currentDirectory ?? driveFileManager.getCachedRootFile()
        let configuration = Configuration(showUploadingFiles: false,
                                          isMultipleSelectionEnabled: false,
                                          rootTitle: KDriveResourcesStrings.Localizable.selectFolderTitle,
                                          emptyViewType: .emptyFolderSelectFolder,
                                          leftBarButtons: nil,
                                          rightBarButtons: currentDirectory.capabilities.canCreateDirectory ? [.addFolder] : nil,
                                          matomoViewPath: [MatomoUtils.View.save.displayName, "SelectFolder"])

        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
    }

    required convenience init(
        driveFileManager: DriveFileManager,
        currentDirectory: File?,
        rightBarButtons: [FileListBarButtonType]?
    ) {
        fatalError("init(driveFileManager:currentDirectory:rightBarButtons:) has not been implemented")
    }
}

final class SelectFolderViewController: FileListViewController {
    lazy var selectFolderButton: IKLargeButton = {
        let button = IKLargeButton(frame: .zero)
        button.setTitle(KDriveResourcesStrings.Localizable.buttonSelectTheFolder, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(selectButtonPressed), for: .touchUpInside)
        return button
    }()

    let disabledDirectoriesSelection: [Int]
    let fileToMove: ProxyFile?
    weak var delegate: SelectFolderDelegate?
    let selectHandler: ((File) -> Void)?

    init(
        viewModel: FileListViewModel,
        disabledDirectoriesSelection: [Int] = [Int](),
        fileToMove: ProxyFile? = nil,
        delegate: SelectFolderDelegate? = nil,
        selectHandler: ((File) -> Void)? = nil
    ) {
        self.disabledDirectoriesSelection = disabledDirectoriesSelection
        self.fileToMove = fileToMove
        self.delegate = delegate
        self.selectHandler = selectHandler
        super.init(viewModel: viewModel)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let bottomPadding = 32.0

        collectionView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.List.floatingButtonPaddingBottom + bottomPadding,
            right: 0
        )

        view.addSubview(selectFolderButton)

        NSLayoutConstraint.activate([
            selectFolderButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            selectFolderButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            selectFolderButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -bottomPadding),
            selectFolderButton.heightAnchor.constraint(equalToConstant: 60)
        ])
        setUpDirectory()
    }

    private func setUpDirectory() {
        let isNotExcluded = !disabledDirectoriesSelection.contains(viewModel.currentDirectory.id)
        let currentDirectory = viewModel.currentDirectory
        let canMoveOrCreate = currentDirectory.capabilities.canMoveInto || currentDirectory.capabilities.canCreateFile
        let selectButtonEnabled = isNotExcluded && canMoveOrCreate

        guard let fileToMove else {
            selectFolderButton.isEnabled = isNotExcluded && canMoveOrCreate
            return
        }

        let withinSameDrive = currentDirectory.driveId == fileToMove.driveId
        selectFolderButton.isEnabled = withinSameDrive && isNotExcluded && canMoveOrCreate
    }

    static func instantiateInNavigationController(driveFileManager: DriveFileManager,
                                                  startDirectory: File? = nil,
                                                  fileToMove: ProxyFile? = nil,
                                                  disabledDirectoriesIdsSelection: [Int],
                                                  delegate: SelectFolderDelegate? = nil,
                                                  selectHandler: ((File) -> Void)? = nil)
        -> TitleSizeAdjustingNavigationController {
        @InjectService var appRouter: AppNavigable
        var viewControllers = [UIViewController]()
        var isCompactView: Bool {
            guard let rootViewController = appRouter.rootViewController else { return false }
            return rootViewController.traitCollection.horizontalSizeClass == .compact
        }

        let locationFolderViewController = LocationFolderViewController(
            driveFileManager: driveFileManager,
            viewModel: SelectFolderViewModel(driveFileManager: driveFileManager, currentDirectory: startDirectory),
            selectMode: true,
            isCompactView: isCompactView,
            disabledDirectoriesSelection: disabledDirectoriesIdsSelection,
            fileToMove: fileToMove,
            locationDelegate: delegate,
            selectHandler: selectHandler
        )
        locationFolderViewController.navigationItem.hideBackButtonText()
        viewControllers.append(locationFolderViewController)

        if let startDirectory {
            var selectViewControllers: [UIViewController] = []
            var directory: File? = startDirectory
            while let selectDirectory = directory,
                  !selectDirectory.isRoot {
                let selectFolderViewController = SelectFolderViewController(
                    viewModel: SelectFolderViewModel(driveFileManager: driveFileManager, currentDirectory: selectDirectory),
                    disabledDirectoriesSelection: disabledDirectoriesIdsSelection,
                    fileToMove: fileToMove,
                    delegate: delegate,
                    selectHandler: selectHandler
                )
                selectFolderViewController.navigationItem.hideBackButtonText()
                selectViewControllers.append(selectFolderViewController)
                directory = selectDirectory.parent
            }
            viewControllers.append(contentsOf: selectViewControllers.reversed())
        }

        let navigationController = TitleSizeAdjustingNavigationController()
        navigationController.setViewControllers(viewControllers, animated: false)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    static func instantiateInNavigationController(driveFileManager: DriveFileManager,
                                                  startDirectory: File? = nil,
                                                  fileToMove: ProxyFile? = nil,
                                                  disabledDirectoriesSelection: [File] = [],
                                                  delegate: SelectFolderDelegate? = nil,
                                                  selectHandler: ((File) -> Void)? = nil)
        -> TitleSizeAdjustingNavigationController {
        let disabledDirectoriesIdsSelection = disabledDirectoriesSelection.map(\.id)
        return instantiateInNavigationController(
            driveFileManager: driveFileManager,
            startDirectory: startDirectory,
            fileToMove: fileToMove,
            disabledDirectoriesIdsSelection: disabledDirectoriesIdsSelection,
            delegate: delegate,
            selectHandler: selectHandler
        )
    }

    // MARK: - Actions

    override func barButtonPressed(_ sender: FileListBarButton) {
        @InjectService var matomo: MatomoUtils
        if sender.type == .cancel {
            dismiss(animated: true)
        } else if sender.type == .addFolder {
            matomo.track(eventWithCategory: .newElement, name: "newFolderOnTheFly")
            let newFolderViewController = NewFolderTypeTableViewController.instantiateInNavigationController(
                parentDirectory: viewModel.currentDirectory,
                driveFileManager: viewModel.driveFileManager
            )
            navigationController?.present(newFolderViewController, animated: true)
        } else {
            super.barButtonPressed(sender)
        }
    }

    @objc func selectButtonPressed() {
        var frozenSelectedDirectory = viewModel.currentDirectory.freezeIfNeeded()
        if !frozenSelectedDirectory.isDirectory, let parent = frozenSelectedDirectory.parent {
            frozenSelectedDirectory = parent.freezeIfNeeded()
        }
        delegate?.didSelectFolder(frozenSelectedDirectory)
        selectHandler?(frozenSelectedDirectory)
        navigationController?.dismiss(animated: true)
    }

    // MARK: - Collection view data source

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let file = displayedFiles[indexPath.row]
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! FileCollectionViewCell

        cell.setEnabled(file.isDirectory && file.id != fileToMove?.id)
        cell.moreButton.isHidden = true
        return cell
    }

    // MARK: - Collection view delegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedFile = displayedFiles[indexPath.row]
        guard let navigationController,
              selectedFile.isDirectory else {
            return
        }

        let destinationViewController = SelectFolderViewController(
            viewModel: SelectFolderViewModel(
                driveFileManager: viewModel.driveFileManager,
                currentDirectory: selectedFile
            ),
            disabledDirectoriesSelection: disabledDirectoriesSelection,
            fileToMove: fileToMove,
            delegate: delegate,
            selectHandler: selectHandler
        )

        navigationController.pushViewController(destinationViewController, animated: true)
    }
}
