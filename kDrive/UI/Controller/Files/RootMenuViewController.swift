/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import InfomaniakCoreUI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

class RootMenuViewController: UICollectionViewController {
    private struct RootMenuItem: Equatable {
        var id: Int {
            return destinationFile.id
        }
        let name: String
        let image: UIImage
        let destinationFile: File
    }

    private static let baseItems: [RootMenuItem] = [RootMenuItem(name: KDriveResourcesStrings.Localizable.favoritesTitle,
                                                                 image: KDriveResourcesAsset.favorite.image,
                                                                 destinationFile: DriveFileManager.favoriteRootFile),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.lastEditsTitle,
                                                                 image: KDriveResourcesAsset.clock.image,
                                                                 destinationFile: DriveFileManager.lastModificationsRootFile),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
                                                                 image: KDriveResourcesAsset.folderSelect2.image,
                                                                 destinationFile: DriveFileManager.sharedWithMeRootFile),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.mySharesTitle,
                                                                 image: KDriveResourcesAsset.folderSelect.image,
                                                                 destinationFile: DriveFileManager.mySharedRootFile),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.offlineFileTitle,
                                                                 image: KDriveResourcesAsset.availableOffline.image,
                                                                 destinationFile: DriveFileManager.offlineRoot),
                                                    RootMenuItem(name: KDriveResourcesStrings.Localizable.trashTitle,
                                                                 image: KDriveResourcesAsset.delete.image,
                                                                 destinationFile: DriveFileManager.trashRootFile)]

    private let driveFileManager: DriveFileManager
    private var rootChildrenObservationToken: NotificationToken?
    private var rootViewChildren: [File]?

    private var items: [RootMenuItem] {
        let userRootFolders = rootViewChildren?.compactMap {
            RootMenuItem(name: $0.name, image: $0.icon, destinationFile: $0)
        } ?? []

        return userRootFolders + RootMenuViewController.baseItems
    }

    init(driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
        super.init(collectionViewLayout: RootMenuViewController.createListLayout())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = driveFileManager.drive.name
        navigationController?.navigationBar.prefersLargeTitles = true
        collectionView.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        collectionView.register(RootMenuCell.self, forCellWithReuseIdentifier: RootMenuCell.identifier)

        let rootChildren = driveFileManager.getRealm()
            .object(ofType: File.self, forPrimaryKey: DriveFileManager.constants.rootID)?.children
        rootChildrenObservationToken = rootChildren?.observe { [weak self] changes in
            guard let self else { return }
            switch changes {
            case .initial(let children):
                rootViewChildren = Array(children)
                collectionView.reloadData()
            case .update(let children, _, _,_):
                rootViewChildren = Array(children)
                // TODO: Maybe use insert/remove instead of reload
                collectionView.reloadData()
            case .error:
                break
            }
        }
    }
    static func createListLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .estimated(60))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(60))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                       subitems: [item])

        let section = NSCollectionLayoutSection(group: group)

        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let rootMenuCell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RootMenuCell.identifier,
            for: indexPath
        ) as? RootMenuCell else {
            fatalError("Failed to dequeue cell")
        }

        let menuItem = items[indexPath.row]
        rootMenuCell.configure(title: menuItem.name, icon: menuItem.image)
        rootMenuCell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == items.count - 1)
        return rootMenuCell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedRootFile = items[indexPath.row].destinationFile

        let destinationViewModel: FileListViewModel
        switch selectedRootFile.id {
        case DriveFileManager.favoriteRootFile.id:
            destinationViewModel = FavoritesViewModel(driveFileManager: driveFileManager)
        case DriveFileManager.lastModificationsRootFile.id:
            destinationViewModel = LastModificationsViewModel(driveFileManager: driveFileManager)
        case DriveFileManager.sharedWithMeRootFile.id:
            navigationController?.pushViewController(SharedDrivesViewController.instantiate(), animated: true)
            return
        case DriveFileManager.offlineRoot.id:
            destinationViewModel = OfflineFilesViewModel(driveFileManager: driveFileManager)
        case DriveFileManager.trashRootFile.id:
            destinationViewModel = TrashListViewModel(driveFileManager: driveFileManager)
        default:
            destinationViewModel = ConcreteFileListViewModel(
                driveFileManager: driveFileManager,
                currentDirectory: selectedRootFile
            )
        }

        let destinationViewController = FileListViewController.instantiate(viewModel: destinationViewModel)
        navigationController?.pushViewController(destinationViewController, animated: true)
    }
}
