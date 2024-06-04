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

import CocoaLumberjackSwift
import InfomaniakConcurrency
import InfomaniakCore
import kDriveCore
import kDriveResources
import Kingfisher
import UIKit

final class StorageTableViewController: UITableViewController {
    private enum Section: CaseIterable {
        case header, directories, files
    }

    private let sections = Section.allCases

    @MainActor private var totalSize: UInt64 = 0
    @MainActor private var directories = [CacheModel]()
    @MainActor private var files = [CacheModel]()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: ParameterTableViewCell.self)
        tableView.separatorStyle = .none
        tableView.backgroundColor = KDriveResourcesAsset.backgroundColor.color

        title = KDriveResourcesStrings.Localizable.manageStorageTitle

        Task {
            await reload()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName, "Storage"])
    }

    private func reload() async {
        // Get directories
        var directoryStorage: [CacheItem] = [CacheItem.fileSystem(url: DriveFileManager.constants.rootDocumentsURL),
                                             CacheItem.fileSystem(url: NSFileProviderManager.default.documentStorageURL),
                                             CacheItem.fileSystem(url: DriveFileManager.constants.importDirectoryURL),
                                             CacheItem.fileSystem(url: FileManager.default.temporaryDirectory),
                                             CacheItem.fileSystem(url: DriveFileManager.constants.cacheDirectoryURL),
                                             CacheItem.storageImageCache]

        if let openInPlaceURL = DriveFileManager.constants.openInPlaceDirectoryURL {
            directoryStorage.append(CacheItem.fileSystem(url: openInPlaceURL))
        }

        // Append document directory if it exists
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory,
                                                            in: .userDomainMask).first {
            directoryStorage.insert(CacheItem.fileSystem(url: documentDirectory), at: 1)
        }

        // Compute cacheDirectories
        let cacheDirectories = await directoryStorage.concurrentMap { CacheModel(datasource: $0) }

        // Compute cacheFiles
        let cacheFilesItems = CacheItem.exploreFiles(for: DriveFileManager.constants.cacheDirectoryURL)
        let cacheFiles = await cacheFilesItems.concurrentMap { CacheModel(datasource: $0) }

        // Compute space usage
        let usedSize = cacheDirectories.reduce(0) { $0 + $1.size }

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.totalSize = usedSize
            self.directories = cacheDirectories
            self.files = cacheFiles
            self.tableView.reloadData()
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .header:
            return 1
        case .directories:
            return directories.count
        case .files:
            return files.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)

        cell.titleLabel.lineBreakMode = .byTruncatingMiddle

        let section = sections[indexPath.section]
        switch section {
        case .header:
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.totalStorageUsedTitle
            cell.valueLabel.text = Constants.formatFileSize(Int64(totalSize))
            cell.selectionStyle = .none
        case .directories:
            let directory = directories[indexPath.row]
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == directories.count - 1)
            cell.titleLabel.text = directory.directoryTitle
            cell.valueLabel.text = directory.formattedSize
            cell.selectionStyle = indexPath.row == 0 ? .none : .default
        case .files:
            let file = files[indexPath.row]
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == files.count - 1)
            cell.titleLabel.text = file.name
            cell.valueLabel.text = file.formattedSize
            cell.selectionStyle = .default
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = sections[section]
        guard section != .header else { return nil }
        let sectionHeaderView = NewFolderSectionHeaderView.instantiate()
        switch section {
        case .header:
            break
        case .directories:
            sectionHeaderView.titleLabel.text = KDriveResourcesStrings.Localizable.directoriesTitle
        case .files:
            sectionHeaderView.titleLabel.text = KDriveResourcesStrings.Localizable.cachedFileTitle
        }
        return sectionHeaderView
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = sections[indexPath.section]
        let storage: CacheModel
        let message: String

        switch section {
        case .header:
            return
        case .directories:
            guard indexPath.row != 0 else { return }
            storage = directories[indexPath.row]
            message = KDriveResourcesStrings.Localizable.modalClearCacheDirectoryDescription(storage.directoryTitle)
        case .files:
            storage = files[indexPath.row]
            message = KDriveResourcesStrings.Localizable.modalClearCacheFileDescription(storage.name)
        }

        let alertViewController = AlertTextViewController(
            title: KDriveResourcesStrings.Localizable.modalClearCacheTitle,
            message: message,
            action: KDriveResourcesStrings.Localizable.buttonClear,
            destructive: true
        ) { [weak self] in
            Task {
                // clean element
                await storage.clean()

                // Reload datasource
                await self?.reload()
            }
        }

        present(alertViewController, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
