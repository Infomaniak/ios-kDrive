/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import Foundation
import kDriveResources
import Kingfisher

/// Something to wrap abstract cache sources
public enum StorageToClean {
    /// The cache is a folder on storage
    case storage(url: URL)

    /// The cache is Kinkfisher image storage on disk
    case storageImageCache

    public var size: UInt64 {
        switch self {
        case .storage(let url):
            let path = url.path
            let size = getPathSize(at: path)
            return size

        case .storageImageCache:
            let cacheSize = try? ImageCache.default.diskStorage.totalSize()
            return UInt64(cacheSize ?? 0)
        }
    }

    /// Recursively explore a path and count total size
    private func getPathSize(at path: String) -> UInt64 {
        var size = getFileSize(at: path)

        // Explore children
        if isDirectory {
            let children = try? FileManager.default.contentsOfDirectory(atPath: path)
            for child in children ?? [] {
                size += getPathSize(at: (path as NSString).appendingPathComponent(child))
            }
        }

        return size
    }

    /// Get the file size of a single file at path
    private func getFileSize(at path: String) -> UInt64 {
        var size: UInt64 = 0
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
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

    var isDirectory: Bool {
        switch self {
        case .storage(let url):
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            return exists && isDirectory.boolValue

        case .storageImageCache:
            return false
        }
    }

    public var name: String {
        switch self {
        case .storage(let url):
            let path = url.path
            return url.lastPathComponent

        case .storageImageCache:
            // TODO: i18n
            return "Image Cache"
        }
    }

    public var directoryTitle: String {
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

    public func clean() {
        switch self {
        case .storage(let url):
            let path = url.path
            let isDirectory = isDirectory

            do {
                try FileManager.default.removeItem(atPath: path)
                guard isDirectory else {
                    return
                }

                // Recreate directory to avoid any issue
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch {
                DDLogError("Failed to remove item for path: \(path) with error: \(error)")
            }

        case .storageImageCache:
            ImageCache.default.clearDiskCache()
        }
    }
}

public struct CleanSpaceActions {
    private let fileManager = FileManager.default

    public init() {
        // Sonar Cloud happy
    }

    public func exploreDirectory(at path: String) -> [StorageToClean] {
        // File exists
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            return []
        }

        // Get children
        if isDir.boolValue {
            var childrenPath = try? fileManager.contentsOfDirectory(atPath: path)
            childrenPath?.removeAll(where: { path in
                path.contains("logs")
            }) // Exclude log files

            guard let childrenPath else {
                return []
            }

            return childrenPath.flatMap { exploreDirectory(at: (path as NSString).appendingPathComponent($0)) }
        } else {
            let url = URL(fileURLWithPath: path)
            return [StorageToClean.storage(url: url)]
        }
    }

    public func getFile(at path: String) -> StorageFile? {
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

        return StorageFile(path: path, size: size)
    }

    public func getFileSize(at path: String) -> UInt64 {
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

    public func delete(file: StorageFile) {
        let isDirectory = file.isDirectory
        do {
            try fileManager.removeItem(atPath: file.path)
            if isDirectory {
                // Recreate directory to avoid any issue
                try fileManager.createDirectory(atPath: file.path, withIntermediateDirectories: true)
            }
        } catch {
            DDLogError("Failed to remove item for path: \(file.path) with error: \(error)")
        }
    }
}
