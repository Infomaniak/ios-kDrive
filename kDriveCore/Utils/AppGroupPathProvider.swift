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

import Foundation
import OSLog

// TODO: Move to core /all

/// Something that can provide a set of common URLs within the app group
///
/// This is shared between all apps of the group initialised with
protocol AppGroupPathProvidable: AnyObject {
    /// Failable init if app group is not found
    init?(appGroupIdentifier: String)

    /// The directory of the current app group, exists in FS.
    /// Uses the `.completeUntilFirstUserAuthentication` protection policy
    var groupDirectoryURL: URL { get }

    /// The root directory of kDrive, exists in FS
    var driveRootDocumentsURL: URL { get }

    /// The import directory, exists in FS
    var importDirectoryURL: URL { get }

    /// The cache directory within the app group, exists in FS
    var cacheDirectoryURL: URL { get }

    /// The temporary directory within the app group, exists in FS
    var tmpDirectoryURL: URL { get }

    /// Open In Place directory if available
    var openInPlaceDirectoryURL: URL? { get }
}

public final class AppGroupPathProvider: AppGroupPathProvidable {
    private var fileManager = FileManager.default

    // MARK: public var
    
    public var groupDirectoryURL: URL

    public lazy var driveRootDocumentsURL: URL = {
        let drivesURL = groupDirectoryURL.appendingPathComponent("drives", isDirectory: true)
        try? fileManager.createDirectory(
            atPath: drivesURL.path,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return drivesURL
    }()

    public lazy var importDirectoryURL: URL = {
        let importURL = groupDirectoryURL.appendingPathComponent("import", isDirectory: true)
        try? fileManager.createDirectory(
            atPath: importURL.path,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return importURL
    }()

    public lazy var cacheDirectoryURL: URL = {
        let cacheURL = groupDirectoryURL.appendingPathComponent("Library/Caches", isDirectory: true)
        try? fileManager.createDirectory(
            atPath: cacheURL.path,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return cacheURL
    }()

    public lazy var tmpDirectoryURL: URL = {
        let tmpURL = groupDirectoryURL.appendingPathComponent("tmp", isDirectory: true)
        try? fileManager.createDirectory(
            atPath: tmpURL.path,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return tmpURL
    }()

    public lazy var openInPlaceDirectoryURL: URL? = {
        let openInPlaceURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(".shared", isDirectory: true)
        return openInPlaceURL
    }()

    // MARK: init
    
    public init?(appGroupIdentifier: String) {
        guard let groupDirectoryURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        else {
            return nil
        }

        do {
            try fileManager.setAttributes(
                [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: groupDirectoryURL.path
            )
        } catch {
            os_log("failed to protect mandatory path")
            return nil
        }

        self.groupDirectoryURL = groupDirectoryURL
    }
}
