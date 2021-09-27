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

    private enum HomeTopRow: Differentiable {
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

    private var topRows = [HomeTopRow]()

    private var showInsufficientStorage = true
    private var uploadCountManager: UploadCountManager!
    var driveFileManager: DriveFileManager! {
        didSet {
            observeUploadCount()
        }
    }

    private var recentFilesController: HomeRecentFilesController?

    override func viewDidLoad() {
        super.viewDidLoad()
        topRows = getTopRows()

        collectionView.register(cellView: HomeRecentFilesSelectorCollectionViewCell.self)
        collectionView.register(WrapperCollectionViewCell.self, forCellWithReuseIdentifier: "WrapperCollectionViewCell")
        collectionView.register(cellView: HomeFileSearchCollectionViewCell.self)
        collectionView.register(cellView: HomeOfflineCollectionViewCell.self)
        collectionView.register(cellView: InsufficientStorageCollectionViewCell.self)
        collectionView.register(cellView: UploadsInProgressCollectionViewCell.self)
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.collectionViewLayout = createLayout()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)

        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] status in
            DispatchQueue.main.async {
                self.reload()
                if status != .offline {}
            }
        }

        recentFilesController = HomePhotoListController(driveFileManager: driveFileManager, homeViewController: self)
    }

    private func getTopRows() -> [HomeTopRow] {
        var topRows: [HomeTopRow]
        if ReachabilityListener.instance.currentStatus == .offline {
            topRows = [.offline, .drive, .search]
        } else {
            topRows = [.drive, .search, .recentFilesSelector]
        }

        if uploadCountManager != nil && uploadCountManager.uploadCount > 0 {
            topRows.append(.uploadsInProgress)
        }

        guard driveFileManager != nil && driveFileManager.drive.size > 0 else {
            return topRows
        }
        let storagePercentage = Double(driveFileManager.drive.usedSize) / Double(driveFileManager.drive.size) * 100
        if (storagePercentage > UIConstants.insufficientStorageMinimumPercentage) && showInsufficientStorage {
            topRows.append(.insufficientStorage)
        }
        return topRows
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
                    self.reload()
                }
            } else {
                // Add cell
                self.reload()
            }
        }
    }

    func reload() {
        let source: [ArraySection<HomeSection, AnyDifferentiable>] = [
            ArraySection(model: .top, elements: topRows.map { AnyDifferentiable($0) }),
            ArraySection(model: .recentFiles, elements: recentFilesController?.displayedFiles.map { AnyDifferentiable($0) } ?? [])
        ]

        let updatedTopRows = getTopRows()
        let updatedFiles = recentFilesController?.fetchedFiles ?? []
        let target: [ArraySection<HomeSection, AnyDifferentiable>] = [
            ArraySection(model: .top, elements: updatedTopRows.map { AnyDifferentiable($0) }),
            ArraySection(model: .recentFiles, elements: updatedFiles.map { AnyDifferentiable($0) })
        ]
        let changeset = StagedChangeset(source: source, target: target)

        collectionView.reload(using: changeset) { _ in
            self.topRows = updatedTopRows
            self.recentFilesController?.displayedFiles = updatedFiles
            self.recentFilesController?.fetchedFiles = nil
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
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        return NSCollectionLayoutSection(group: group)
    }
}

extension HomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch HomeSection.allCases[section] {
        case .top:
            return topRows.count
        case .recentFiles:
            return recentFilesController?.displayedFiles.count ?? 0
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
            let cellType: UICollectionViewCell.Type
            switch recentFilesController!.listStyle {
            case .list:
                cellType = FileCollectionViewCell.self
            case .grid:
                cellType = FileGridCollectionViewCell.self
            }
            let cell = collectionView.dequeueReusableCell(type: cellType, for: indexPath) as! FileCollectionViewCell

            let displayedFiles = recentFilesController!.displayedFiles
            let file = displayedFiles[indexPath.row]
            cell.initStyle(isFirst: indexPath.row == 0, isLast: indexPath.row == displayedFiles.count - 1)
            cell.configureWith(file: file, selectionMode: false)

            return cell
        }
    }
}

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if HomeSection.allCases[indexPath.section] == .recentFiles {
            if indexPath.row >= (recentFilesController?.displayedFiles.count ?? 0) - 10 {
                recentFilesController?.loadFiles()
            }
        }
    }
}
