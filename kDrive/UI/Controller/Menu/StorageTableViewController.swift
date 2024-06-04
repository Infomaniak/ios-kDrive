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
import kDriveCore
import kDriveResources
import Kingfisher
import UIKit

final class StorageTableViewController: UITableViewController {
    private let cleanActions = CleanSpaceActions()

    private enum Section: CaseIterable {
        case header, directories, files
    }

    private let sections = Section.allCases

    private var totalSize: UInt64 = 0
    private var directories = [StorageToClean]()
    private var files = [StorageToClean]()

    // adjust for image cache size
    var imageCacheSize: UInt64 {
        let cacheSize = try? ImageCache.default.diskStorage.totalSize()
        return UInt64(cacheSize ?? 0)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: ParameterTableViewCell.self)
        tableView.separatorStyle = .none
        tableView.backgroundColor = KDriveResourcesAsset.backgroundColor.color

        title = KDriveResourcesStrings.Localizable.manageStorageTitle

        reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName, "Storage"])
    }

    private func reload() {
        totalSize = 0

        // Get directories
        var directoryStorage: [StorageToClean] = [StorageToClean.storage(url: DriveFileManager.constants.rootDocumentsURL),
                                                  StorageToClean.storage(url: NSFileProviderManager.default.documentStorageURL),
                                                  StorageToClean.storage(url: DriveFileManager.constants.importDirectoryURL),
                                                  StorageToClean.storage(url: FileManager.default.temporaryDirectory),
                                                  StorageToClean.storage(url: DriveFileManager.constants.cacheDirectoryURL),
                                                  StorageToClean.storageImageCache]

        if let openInPlaceURL = DriveFileManager.constants.openInPlaceDirectoryURL {
            directoryStorage.append(StorageToClean.storage(url: openInPlaceURL))
        }

        // Append document directory if it exists
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory,
                                                            in: .userDomainMask).first {
            directoryStorage.insert(StorageToClean.storage(url: documentDirectory), at: 1)
        }

        directories = directoryStorage

        // Get total size
        totalSize = directories.reduce(0) { $0 + $1.size }

        // Get files
        files = cleanActions.exploreDirectory(at: DriveFileManager.constants.cacheDirectoryURL.path)
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
            cell.valueLabel.text = Constants.formatFileSize(Int64(directory.size))
            cell.selectionStyle = indexPath.row == 0 ? .none : .default
        case .files:
            let file = files[indexPath.row]
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == files.count - 1)
            cell.titleLabel.text = file.name
            cell.valueLabel.text = Constants.formatFileSize(Int64(file.size))
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
        let storage: StorageToClean
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
            DispatchQueue.global(qos: .utility).async {
                guard let self else {
                    return
                }

                storage.clean()

                // Reload data
                self.reload()
                Task { @MainActor [weak self] in
                    self?.tableView.reloadData()
                }
            }
        }
        present(alertViewController, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
