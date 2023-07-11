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

/// Extending NSItemProvider for detecting file type
extension NSItemProvider {
    public enum ItemUnderlyingType {
        /// The item is an URL
        case isURL
        /// The item is Text
        case isText
        /// The item is an UIImage
        case isUIImage
        /// The item is image Data (heic or jpg)
        case isImageData
        /// The item is a Directory
        case isDirectory
        /// The item is a compressed file
        case isCompressedData(identifier: String)
        /// The item is of a miscellaneous type
        case isMiscellaneous(identifier: String)
        /// This should not happen, no type identifier was found
        case none
    }

    /// Wrapping business logic of supported types by the apps.
    var underlyingType: ItemUnderlyingType {
        if hasItemConformingToTypeIdentifier(UTI.url.identifier) && registeredTypeIdentifiers.count == 1 {
            return .isURL
        } else if hasItemConformingToTypeIdentifier(UTI.plainText.identifier)
            && !hasItemConformingToTypeIdentifier(UTI.fileURL.identifier)
            && canLoadObject(ofClass: String.self) {
            return .isText
        } else if hasItemConformingToTypeIdentifier(UTI.directory.identifier) ||
            hasItemConformingToTypeIdentifier(UTI.folder.identifier) {
            return .isDirectory
        } else if hasItemConformingToTypeIdentifier(UTI.zip.identifier)
            || hasItemConformingToTypeIdentifier(UTI.bz2.identifier)
            || hasItemConformingToTypeIdentifier(UTI.gzip.identifier)
            || hasItemConformingToTypeIdentifier(UTI.archive.identifier),
            let typeIdentifier = registeredTypeIdentifiers.first {
            return .isCompressedData(identifier: typeIdentifier)
        } else if registeredTypeIdentifiers.count == 1 &&
            registeredTypeIdentifiers.first == UTI.image.identifier {
            return .isUIImage
        } else if hasItemConformingToTypeIdentifier(UTI.heic.identifier) ||
            hasItemConformingToTypeIdentifier(UTI.jpeg.identifier) {
            return .isImageData
        } else if let typeIdentifier = registeredTypeIdentifiers.first {
            return .isMiscellaneous(identifier: typeIdentifier)
        } else {
            return .none
        }
    }
}
