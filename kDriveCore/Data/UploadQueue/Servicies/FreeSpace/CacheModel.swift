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

/// Something to be used for UI, wrapping a CacheItem
public struct CacheModel {
    private let datasource: CacheItem

    public let size: UInt64

    public let formattedSize: String

    public let isDirectory: Bool

    public let name: String

    public let directoryTitle: String

    public init(datasource: CacheItem) {
        self.datasource = datasource
        let datasourceSize = datasource.size
        size = datasourceSize
        formattedSize = Constants.formatFileSize(Int64(datasourceSize))
        isDirectory = datasource.isDirectory
        name = datasource.name
        directoryTitle = datasource.directoryTitle
    }

    public func clean() async {
        await datasource.clean()
    }
}

/// Represents abstract cache item (file/ folder/ cache library …)
public enum CacheItem {
    /// The cache is a folder or a file on file system
    case fileSystem(url: URL)

    /// The cache is Kingfisher image storage on disk
    case storageImageCache

    /// Generate a collection of StorageToClean files from a source URL
    public static func exploreFiles(for url: URL) -> [CacheItem] {
        guard isDirectory(url: url) else {
            #if DEBUG
            return [CacheItem.fileSystem(url: url)]
            #else
            // Do not show log files in production
            guard !url.lastPathComponent.hasSuffix(".log") else {
                return []
            }
            return [CacheItem.fileSystem(url: url)]
            #endif
        }

        // Explore children
        let children = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? [URL]()

        let storages = children.reduce([CacheItem]()) { partial, child in
            return partial + CacheItem.exploreFiles(for: child)
        }
        return storages
    }

    public var size: UInt64 {
        switch self {
        case .fileSystem(let url):
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
        case .fileSystem(let url):
            return Self.isDirectory(url: url)

        case .storageImageCache:
            return false
        }
    }

    private static func isDirectory(url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    public var name: String {
        switch self {
        case .fileSystem(let url):
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
        case ".shared":
            // TODO: i18n
            return "Open in place"
        default:
            return name.capitalized
        }
    }

    public func clean() async {
        switch self {
        case .fileSystem(let url):
            let isDirectory = isDirectory

            do {
                try FileManager.default.removeItem(at: url)
                guard isDirectory else {
                    return
                }

                // Recreate directory to avoid any issue
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                DDLogError("Failed to remove item for path: \(url) with error: \(error)")
            }

        case .storageImageCache:
            ImageCache.default.clearDiskCache()

            /// wait for the non await-able image cache library to process
            try? await Task.sleep(nanoseconds: 350_000_000)
        }
    }
}
