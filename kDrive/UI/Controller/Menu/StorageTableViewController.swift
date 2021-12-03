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
import UIKit

class StorageTableViewController: UITableViewController {
    private enum Section: CaseIterable {
        case header, directories, files
    }

    private struct File {
        let path: String
        let size: UInt64

        var name: String {
            return (path as NSString).lastPathComponent
        }

        var isDirectory: Bool {
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            return exists && isDir.boolValue
        }

        var directoryTitle: String {
            switch name {
            case "drives":
                return KDriveResourcesStrings.Localizable.drivesDirectory
            case "Documents":
                return KDriveResourcesStrings.Localizable.documentsDirectory
            case "import":
                return KDriveResourcesStrings.Localizable.importDirectory
            case "tmp":
                return KDriveResourcesStrings.Localizable.tempDirectory
            case "Caches":
                return KDriveResourcesStrings.Localizable.cacheDirectory
            default:
                return name.capitalized
            }
        }
    }

    private let fileManager = FileManager.default
    private let sections = Section.allCases

    private var totalSize: UInt64 = 0
    private var directories = [File]()
    private var files = [File]()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: ParameterTableViewCell.self)
        tableView.separatorStyle = .none
        tableView.backgroundColor = KDriveResourcesAsset.backgroundColor.color

        title = KDriveResourcesStrings.Localizable.manageStorageTitle

        reload()
    }

    private func reload() {
        totalSize = 0
        // Get directories
        var paths = [DriveFileManager.constants.rootDocumentsURL,
                     NSFileProviderManager.default.documentStorageURL,
                     DriveFileManager.constants.importDirectoryURL,
                     fileManager.temporaryDirectory,
                     DriveFileManager.constants.cacheDirectoryURL]
        // Append document directory if it exists
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            paths.insert(documentDirectory, at: 1)
        }
        directories = paths.compactMap { getFile(at: $0.path) }
        // Get total size
        totalSize = directories.reduce(0) { $0 + $1.size }
        // Get files
        files = exploreDirectory(at: DriveFileManager.constants.cacheDirectoryURL.path) ?? []
        files.removeAll { $0.path.contains("logs") } // Exclude log files
    }

    private func exploreDirectory(at path: String) -> [File]? {
        // File exists
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            return nil
        }
        // Get size
        let size = getFileSize(at: path)
        // Get children
        if isDir.boolValue {
            let childrenPath = try? fileManager.contentsOfDirectory(atPath: path)
            return childrenPath?.flatMap { exploreDirectory(at: (path as NSString).appendingPathComponent($0)) ?? [] }
        } else {
            return [File(path: path, size: size)]
        }
    }

    private func getFile(at path: String) -> File? {
        // File exists
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            return nil
        }
        // Get size
        var size = getFileSize(at: path)
        // Explore children
        if isDir.boolValue {
            let children = try? fileManager.contentsOfDirectory(atPath: path)
            for child in children ?? [] {
                size += getFile(at: (path as NSString).appendingPathComponent(child))?.size ?? 0
            }
        }
        return File(path: path, size: size)
    }

    private func getFileSize(at path: String) -> UInt64 {
        var size: UInt64 = 0
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            if let sizeAttribute = attributes[.size] as? NSNumber {
                size = sizeAttribute.uint64Value
            } else {
                DDLogError("Failed to get a size attribute from path: \(path)")
            }
        } catch {
            DDLogError("Failed to get file attributes for path: \(path) with error: \(error)")
        }
        return size
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
        let file: File
        let message: String
        switch section {
        case .header:
            return
        case .directories:
            guard indexPath.row != 0 else { return }
            file = directories[indexPath.row]
            message = KDriveResourcesStrings.Localizable.modalClearCacheDirectoryDescription(file.directoryTitle)
        case .files:
            file = files[indexPath.row]
            message = KDriveResourcesStrings.Localizable.modalClearCacheFileDescription(file.name)
        }
        let alertViewController = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalClearCacheTitle, message: message, action: KDriveResourcesStrings.Localizable.buttonClear, destructive: true) {
            let isDirectory = file.isDirectory
            do {
                try self.fileManager.removeItem(atPath: file.path)
                if isDirectory {
                    // Recreate directory to avoid any issue
                    try self.fileManager.createDirectory(atPath: file.path, withIntermediateDirectories: true)
                }
            } catch {
                DDLogError("Failed to remove item for path: \(file.path) with error: \(error)")
            }
            self.reload()
            self.tableView.reloadData()
        }
        present(alertViewController, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
