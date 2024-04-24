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

public struct StorageFile {
    public let path: String
    public let size: UInt64

    public init(path: String, size: UInt64) {
        self.path = path
        self.size = size
    }

    public var name: String {
        return (path as NSString).lastPathComponent
    }

    public var isDirectory: Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
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
}

public struct CleanSpaceActions {
    private let fileManager = FileManager.default

    public init() {
        // Sonar Cloud happy
    }

    public func exploreDirectory(at path: String) -> [StorageFile]? {
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
            return [StorageFile(path: path, size: size)]
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
