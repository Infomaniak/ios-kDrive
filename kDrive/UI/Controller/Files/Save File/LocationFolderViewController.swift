/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

class LocationFolderViewController: RootMenuViewController {
    private var selectedIndexPath: IndexPath?
    weak var delegate: SelectFolderDelegate?

    private static let recentItems: [RootMenuItem] = [RootMenuItem(name: KDriveResourcesStrings.Localizable.lastEditsTitle,
                                                                   image: KDriveResourcesAsset.clock.image,
                                                                   destinationFile: DriveFileManager
                                                                       .lastModificationsRootFile)]

    private static let mainItems: [RootMenuItem] = [RootMenuItem(name: KDriveResourcesStrings.Localizable.favoritesTitle,
                                                                 image: KDriveResourcesAsset.favorite.image,
                                                                 destinationFile: DriveFileManager.favoriteRootFile),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
                                                                 image: KDriveResourcesAsset.folderSelect2.image,
                                                                 destinationFile: DriveFileManager.sharedWithMeRootFile),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.mySharesTitle,
                                                                 image: KDriveResourcesAsset.folderSelect.image,
                                                                 destinationFile: DriveFileManager.mySharedRootFile)]

    var viewModel: FileListViewModel
    private var rootChildrenObservationToken: NotificationToken?
    private var dataSource: MenuDataSource?
    override var itemsSnapshot: DataSourceSnapshot {
        var snapshot = DataSourceSnapshot()
        let userRootFolders = rootViewChildren?.compactMap {
            RootMenuItem(
                name: $0.formattedLocalizedName(drive: driveFileManager.drive),
                image: $0.icon,
                destinationFile: $0
            )
        } ?? []

        let recentFrozenFoldersSlice = driveFileManager.database.fetchResults(ofType: File.self) { lazyCollection in
            lazyCollection
                .filter("rawType == %@", FileType.dir.rawValue)
                .filter("id > %@", DriveFileManager.constants.rootID)
                .filter("parentId > %@", DriveFileManager.constants.rootID)
                .sorted(byKeyPath: "lastModifiedAt", ascending: false)
                .freeze()
        }.prefix(3)
        let recentFrozenFolders = Array(recentFrozenFoldersSlice)

        let recentDirectories = recentFrozenFolders.enumerated().map { index, file in
            RootMenuItem(
                name: file.name,
                image: file.icon,
                destinationFile: file,
                isFirst: index == 0,
                isLast: index == recentFrozenFolders.count - 1
            )
        }

        let firstSectionItems = recentDirectories
        let secondSectionItems = userRootFolders + LocationFolderViewController.mainItems
        let sections = [RootMenuSection.recent, RootMenuSection.main]
        let sectionItems = [firstSectionItems, secondSectionItems]

        for i in 0 ... sectionItems.count - 1 {
            guard var sectionItem = sectionItems[safe: i] else { continue }
            guard let section = sections[safe: i] else { continue }
            if !sectionItem.isEmpty {
                sectionItem[0].isFirst = true
                sectionItem[sectionItem.count - 1].isLast = true

                snapshot.appendSections([section])
                snapshot.appendItems(sectionItem, toSection: section)
            }
        }

        return snapshot
    }

    init(
        driveFileManager: DriveFileManager,
        viewModel: FileListViewModel,
        selectMode: Bool,
        delegate: SelectFolderDelegate? = nil
    ) {
        self.viewModel = viewModel
        self.delegate = delegate
        super.init(driveFileManager: driveFileManager, selectMode: selectMode)
    }

    @objc func closeButtonPressed() {
        dismiss(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let closeButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
        closeButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
        navigationItem.title = driveFileManager.drive.name
        navigationItem.leftBarButtonItem = closeButton
        navigationItem.rightBarButtonItem = nil

        dataSource = configureDataSource(for: collectionView)
        setItemsSnapshot(for: collectionView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        saveSceneState()
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedRootFile = dataSource?.itemIdentifier(for: indexPath)?.destinationFile else { return }
        let destinationViewModel: FileListViewModel

        switch selectedRootFile.id {
        case DriveFileManager.favoriteRootFile.id:
            destinationViewModel = FavoritesViewModel(driveFileManager: driveFileManager)
        case DriveFileManager.sharedWithMeRootFile.id:
            let sharedWithMeDriveFileManager = driveFileManager.instanceWith(context: .sharedWithMe)
            destinationViewModel = SharedWithMeViewModel(driveFileManager: sharedWithMeDriveFileManager)
        case DriveFileManager.mySharedRootFile.id:
            destinationViewModel = MySharesViewModel(driveFileManager: driveFileManager)
        case DriveFileManager.lastModificationsRootFile.id:
            destinationViewModel = LastModificationsViewModel(driveFileManager: driveFileManager)
        default:
            destinationViewModel = ConcreteFileListViewModel(
                driveFileManager: driveFileManager,
                currentDirectory: selectedRootFile,
                rightBarButtons: viewModel.currentRightBarButtons
            )
        }

        let destinationViewController = SelectFolderViewController(viewModel: destinationViewModel, delegate: delegate)
        destinationViewModel.onDismissViewController = { [weak destinationViewController] in
            destinationViewController?.dismiss(animated: true)
        }

        navigationController?.pushViewController(destinationViewController, animated: true)
    }
}
