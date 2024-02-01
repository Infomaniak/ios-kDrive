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

import Alamofire
import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import InfomaniakDI
import InfomaniakLogin
import RealmSwift
import SwiftRegex

public final class DriveConstants {
    private let fileManager = FileManager.default

    public let rootDocumentsURL: URL
    public let importDirectoryURL: URL
    public let groupDirectoryURL: URL
    public var cacheDirectoryURL: URL
    public var tmpDirectoryURL: URL
    public let openInPlaceDirectoryURL: URL?

    public let rootID = 1
    public let currentVersionCode = 1

    public let driveObjectTypes = [
        File.self,
        Rights.self,
        FileActivity.self,
        FileCategory.self,
        FileConversion.self,
        FileVersion.self,
        FileExternalImport.self,
        ShareLink.self,
        ShareLinkCapabilities.self,
        DropBox.self,
        DropBoxCapabilities.self,
        DropBoxSize.self,
        DropBoxValidity.self
    ]

    public init() {
        @InjectService var pathProvider: AppGroupPathProvidable
        groupDirectoryURL = pathProvider.groupDirectoryURL
        rootDocumentsURL = pathProvider.realmRootURL
        importDirectoryURL = pathProvider.importDirectoryURL
        tmpDirectoryURL = pathProvider.tmpDirectoryURL
        cacheDirectoryURL = pathProvider.cacheDirectoryURL
        openInPlaceDirectoryURL = pathProvider.openInPlaceDirectoryURL

        DDLogInfo(
            "App working path is: \(fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.absoluteString ?? "")"
        )
        DDLogInfo("Group container path is: \(groupDirectoryURL.absoluteString)")
    }
}
