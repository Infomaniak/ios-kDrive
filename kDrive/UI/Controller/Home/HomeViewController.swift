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

import DifferenceKit
import InfomaniakCore
import kDriveCore
import UIKit

protocol HomeFileDelegate: AnyObject {
    func didSelect(index: Int, files: [File])
}

class HomeViewController: UIViewController, SwitchDriveDelegate, SwitchAccountDelegate, HomeFileDelegate, TopScrollable {
    func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
        driveFileManager = newDriveFileManager
    }

    func didUpdateCurrentAccountInformations(_ currentAccount: Account) {}

    func didSwitchCurrentAccount(_ newAccount: Account) {}

    func didSelect(index: Int, files: [File]) {}

    func scrollToTop() {}

    @IBOutlet var collectionView: UICollectionView!

    private enum HomeSection: Differentiable, CaseIterable {
        case top
        case recentFiles
    }

    private enum HomeTopRows {
        case offline
        case drive
        case search
        case insufficientStorage
        case uploadsInProgress
        case recentFilesSelector
    }

    private enum RecentFileRows {
        case recentFiles
    }

    private var topRows = [HomeTopRows]()

    private var showInsufficientStorage = true
    private var uploadCountManager: UploadCountManager!
    var driveFileManager: DriveFileManager! {
        didSet {
            observeUploadCount()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateTopRows()

        collectionView.register(cellView: HomeRecentFilesSelectorCollectionViewCell.self)
        collectionView.register(cellView: WrapperCollectionViewCell.self)
        collectionView.register(cellView: HomeFileSearchCollectionViewCell.self)
        collectionView.register(cellView: HomeOfflineCollectionViewCell.self)
        collectionView.register(cellView: InsufficientStorageCollectionViewCell.self)
        collectionView.register(cellView: UploadsInProgressCollectionViewCell.self)
        collectionView.collectionViewLayout = createLayout()
        collectionView.dataSource = self
    }

    private func updateTopRows() {
        if ReachabilityListener.instance.currentStatus == .offline {
            topRows = [.offline, .drive, .search]
        } else {
            topRows = [.uploadsInProgress, .insufficientStorage, .drive, .search, .recentFilesSelector]
        }

        if uploadCountManager != nil && uploadCountManager.uploadCount > 0 {
            topRows.append(.uploadsInProgress)
        }

        guard driveFileManager != nil && driveFileManager.drive.size > 0 else {
            return
        }
        let storagePercentage = Double(driveFileManager.drive.usedSize) / Double(driveFileManager.drive.size) * 100
        if (storagePercentage > UIConstants.insufficientStorageMinimumPercentage) && showInsufficientStorage {
            topRows.append(.insufficientStorage)
        }
    }

    private func observeUploadCount() {
        guard driveFileManager != nil else { return }
        uploadCountManager = UploadCountManager(driveFileManager: driveFileManager) { [weak self] in
            guard let self = self else { return }
            if let index = self.topRows.firstIndex(where: { $0 == .uploadsInProgress }),
               let cell = self.collectionView.cellForItem(at: IndexPath(row: index, section: 0)) as? UploadsInProgressCollectionViewCell {
                if self.uploadCountManager.uploadCount > 0 {
                    // Update cell
                    cell.setUploadCount(self.uploadCountManager.uploadCount)
                } else {
                    // Delete cell
                    // self.reload(sections: [.top])
                }
            } else {
                // Add cell
                // self.reload(sections: [.top])
            }
        }
    }

    func presentedFromTabBar() {}

    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (section: Int,
                                                            _: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            switch HomeSection.allCases[section] {
            case .top:
                return self.generateTopSectionLayout()
            case .recentFiles:
                return self.generateRecentFilesLayout()
            }
        }
        return layout
    }

    private func generateTopSectionLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        return NSCollectionLayoutSection(group: group)
    }

    private func generateRecentFilesLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        return NSCollectionLayoutSection(group: group)
    }
}

extension HomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch HomeSection.allCases[section] {
        case .top:
            return topRows.count
        case .recentFiles:
            return 0
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return HomeSection.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch HomeSection.allCases[indexPath.section] {
        case .top:
            switch topRows[indexPath.row] {
            case .offline:
                let cell = collectionView.dequeueReusableCell(type: HomeOfflineCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                return cell
            case .drive:
                let cell = collectionView.dequeueReusableCell(type: WrapperCollectionViewCell.self, for: indexPath)
                let tableCell = cell.initWith(cell: DriveSwitchTableViewCell.self)
                tableCell.style = .home
                tableCell.initWithPositionAndShadow(isFirst: true, isLast: true)
                tableCell.configureWith(drive: driveFileManager.drive)
                return cell
            case .search:
                let cell = collectionView.dequeueReusableCell(type: HomeFileSearchCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                return cell
            case .insufficientStorage:
                let cell = collectionView.dequeueReusableCell(type: InsufficientStorageCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.configureCell(with: driveFileManager.drive)
                cell.actionHandler = { [weak self] _ in
                    cell.actionHandler = { [weak self] _ in
                        guard let self = self else { return }
                        StorePresenter.showStore(from: self, driveFileManager: self.driveFileManager)
                    }
                }
                cell.closeHandler = { [weak self] _ in
                    guard let self = self else { return }
                    self.topRows.remove(at: self.topRows.count - 1)
                    collectionView.deleteItems(at: [indexPath])
                    self.showInsufficientStorage = false
                }
                return cell
            case .uploadsInProgress:
                let cell = collectionView.dequeueReusableCell(type: UploadsInProgressCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.progressView.enableIndeterminate()
                cell.setUploadCount(uploadCountManager.uploadCount)
                return cell
            case .recentFilesSelector:
                let cell = collectionView.dequeueReusableCell(type: HomeRecentFilesSelectorCollectionViewCell.self, for: indexPath)
                return cell
            }
        case .recentFiles:
            return UICollectionViewCell()
        }
    }
}
