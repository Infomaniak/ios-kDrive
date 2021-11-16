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

public extension URL {
    var typeIdentifier: String? {
        if hasDirectoryPath {
            return UTI.folder.identifier
        }
        if FileManager.default.fileExists(atPath: path) {
            return try? resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
        } else {
            // If the file is not downloaded, we get the type identifier using its extension
            return UTI(filenameExtension: pathExtension, conformingTo: .item)?.identifier
        }
    }

    var uti: UTI? {
        if let typeIdentifier = typeIdentifier {
            return UTI(typeIdentifier)
        }
        return nil
    }

    var creationDate: Date? {
        return try? resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    func appendingPathExtension(for contentType: UTI) -> URL {
        if let newExtension = contentType.preferredFilenameExtension {
            if pathExtension == newExtension {
                return self
            } else {
                return appendingPathExtension(newExtension)
            }
        }
        return self
    }

    mutating func appendPathExtension(for contentType: UTI) {
        self = appendingPathExtension(for: contentType)
    }
}
