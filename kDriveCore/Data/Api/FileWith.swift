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

import Foundation

enum FileWith: String, CaseIterable {
    case capabilities
    case categories
    case conversionCapabilities = "conversion_capabilities"
    case dropbox
    case dropboxCapabilities = "dropbox.capabilities"
    case externalImport = "external_import"
    case file
    case fileCapabilities = "file.capabilities"
    case fileCategories = "file.categories"
    case fileConversionCapabilities = "file.conversion_capabilities"
    case fileDropbox = "file.dropbox"
    case fileDropboxCapabilities = "file.dropbox.capabilities"
    case fileExternalImport = "file.external_import"
    case fileIsFavorite = "file.is_favorite"
    case fileShareLink = "file.sharelink"
    case fileSortedName = "file.sorted_name"
    case fileSupportedBy = "file.supported_by"
    case isFavorite = "is_favorite"
    case path
    case shareLink = "sharelink"
    case sortedName = "sorted_name"
    case supportedBy = "supported_by"
    case users
    case user
    case version

    case files
    case filesCapabilities = "files.capabilities"
    case filesPath = "files.path"
    case filesSortedName = "files.sorted_name"
    case filesDropbox = "files.dropbox"
    case filesDropboxCapabilities = "files.dropbox.capabilities"
    case filesIsFavorite = "files.is_favorite"
    case filesShareLink = "files.sharelink"
    case filesCategories = "files.categories"
    case filesConversionCapabilities = "files.conversion_capabilities"
    case filesExternalImport = "files.external_import"
    case filesSupportedBy = "files.supported_by"

    static let fileMinimal: [FileWith] = [.capabilities,
                                          .categories,
                                          .conversionCapabilities,
                                          .dropbox,
                                          .dropboxCapabilities,
                                          .externalImport,
                                          .isFavorite,
                                          .shareLink,
                                          .sortedName,
                                          .supportedBy]
    static let fileListingMinimal: [FileWith] = [.files,
                                                 .filesCapabilities,
                                                 .filesCategories,
                                                 .filesConversionCapabilities,
                                                 .filesDropbox,
                                                 .filesDropboxCapabilities,
                                                 .filesExternalImport,
                                                 .filesIsFavorite,
                                                 .filesShareLink,
                                                 .filesSortedName,
                                                 .filesSupportedBy]
    static let fileExtra: [FileWith] = fileMinimal + [.path, .users, .version]
    static let fileActivities: [FileWith] = [.file,
                                             .fileCapabilities,
                                             .fileCategories,
                                             .fileConversionCapabilities,
                                             .fileDropbox,
                                             .fileDropboxCapabilities,
                                             .fileIsFavorite,
                                             .fileShareLink,
                                             .fileSortedName,
                                             .fileSupportedBy]
    static let fileActivitiesWithExtra: [FileWith] = fileActivities + [.fileExternalImport]
    static let fileUpload: [FileWith] = [.capabilities,
                                         .categories,
                                         .conversionCapabilities,
                                         .isFavorite,
                                         .shareLink,
                                         .sortedName]

    static let chunkUpload: [FileWith] = [.capabilities,
                                          .conversionCapabilities,
                                          .sortedName]
}

extension [FileWith] {
    func toQueryItem() -> URLQueryItem {
        URLQueryItem(
            name: "with",
            value: map(\.rawValue).joined(separator: ",")
        )
    }
}
