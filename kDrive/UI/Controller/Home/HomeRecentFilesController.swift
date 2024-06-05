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
import Foundation
import InfomaniakCore
import kDriveCore
import UIKit

@MainActor
class HomeRecentFilesController {
    static let updateDelay: TimeInterval = 60 // 1 minute
    private var lastUpdate = Date()

    let driveFileManager: DriveFileManager
    weak var homeViewController: HomeViewController?

    private let gridMinColumns = 2
    private let gridCellMaxWidth = 200.0
    private let gridCellRatio = 3.0 / 4.0

    let selectorTitle: String
    let title: String
    let emptyCellType: EmptyTableView.EmptyTableViewType
    let listCellType: UICollectionViewCell.Type
    let gridCellType: UICollectionViewCell.Type

    var listStyle: ListStyle = .list
    var listStyleEnabled: Bool
    var page = 1
    var empty = false
    var loading = false
    var moreComing = true
    var invalidated = false

    private var files = [File]()

    init(
        driveFileManager: DriveFileManager,
        homeViewController: HomeViewController,
        listCellType: UICollectionViewCell.Type,
        gridCellType: UICollectionViewCell.Type,
        emptyCellType: EmptyTableView.EmptyTableViewType,
        title: String,
        selectorTitle: String,
        listStyleEnabled: Bool
    ) {
        self.title = title
        self.selectorTitle = selectorTitle
        self.listCellType = listCellType
        self.gridCellType = gridCellType
        self.emptyCellType = emptyCellType
        self.listStyleEnabled = listStyleEnabled

        self.driveFileManager = driveFileManager
        self.homeViewController = homeViewController
    }

    func viewDidAppear() {
        refresh()
    }

    func getFiles() async throws -> [File] {
        fatalError(#function + " needs to be overwritten")
    }

    func restoreCachedPages() {
        invalidated = false
        homeViewController?.reloadWith(fetchedFiles: .file(files), isEmpty: empty)
        refreshIfNeeded()
    }

    func refreshIfNeeded() {
        if Date().timeIntervalSince(lastUpdate) > HomeRecentFilesController.updateDelay {
            forceRefresh()
        }
    }

    func refreshIfNeeded(with file: File) {
        if filesContain(file) {
            forceRefresh()
        }
    }

    func filesContain(_ file: File) -> Bool {
        return files.contains { $0.id == file.id }
    }

    func forceRefresh() {
        lastUpdate = Date()
        loadNextPage(forceRefresh: true)
    }

    // Reload content from DB without triggering a network call
    func refresh() {
        resetController()
        loadNextPage(forceRefresh: false)
    }

    func resetController() {
        files = []
        page = 1
        loading = false
        moreComing = true
    }

    func loadNextPage(forceRefresh: Bool = false) {
        if forceRefresh {
            resetController()
        }

        invalidated = false
        guard !loading && moreComing else {
            return
        }

        loading = true
        Task {
            do {
                let fetchedFiles = try await getFiles()
                self.files.append(contentsOf: fetchedFiles)
                self.empty = self.page == 1 && fetchedFiles.isEmpty
                self.moreComing = fetchedFiles.count == Endpoint.itemsPerPage
                self.page += 1

                guard !self.invalidated else {
                    return
                }
                self.homeViewController?.reloadWith(fetchedFiles: .file(self.files), isEmpty: self.empty)
            } catch {
                UIConstants.showSnackBarIfNeeded(error: error)
            }
            self.loading = false
        }
    }

    func getEmptyLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)

        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = [getHeaderLayout()]
        return section
    }

    func configureEmptyCell(_ cell: HomeEmptyFilesCollectionViewCell) {
        cell.configureCell(with: emptyCellType)
    }

    func getHeaderLayout() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(55))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        return header
    }

    func getLayout(for style: ListStyle, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        var section: NSCollectionLayoutSection
        switch style {
        case .list:
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
            section = NSCollectionLayoutSection(group: group)
        case .grid:
            // Compute number of columns based on collection view size
            let screenWidth = layoutEnvironment.container.effectiveContentSize.width
            let maxColumns = Int(screenWidth / gridCellMaxWidth)
            let columns = max(gridMinColumns, maxColumns)

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalWidth(1 / Double(columns) * gridCellRatio)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24 - 8, bottom: 0, trailing: 24 - 8)
            section = NSCollectionLayoutSection(group: group)
        }
        section.boundarySupplementaryItems = [getHeaderLayout()]
        return section
    }

    class func initInstance(driveFileManager: DriveFileManager, homeViewController: HomeViewController) -> Self {
        fatalError("initInstance must be overridden")
    }
}
