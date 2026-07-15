/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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

import DifferenceKit
import kDriveCore

enum FileListSectionID: Hashable {
    case uploads
    case files
}

enum FileListItem: Differentiable {
    case uploadCard
    case file(File)

    var differenceIdentifier: String {
        switch self {
        case .uploadCard:
            return "upload-card"
        case .file(let file):
            return "file-\(file.id)"
        }
    }

    func isContentEqual(to source: FileListItem) -> Bool {
        switch (self, source) {
        case (.uploadCard, .uploadCard):
            return true
        case (.file(let lhs), .file(let rhs)):
            return lhs.isContentEqual(to: rhs)
        default:
            return false
        }
    }
}

struct FileListSection: DifferentiableSection {
    var id: FileListSectionID
    var elements: [FileListItem]

    var differenceIdentifier: FileListSectionID {
        id
    }

    init<C: Swift.Collection>(
        source: FileListSection,
        elements: C
    ) where C.Element == FileListItem {
        id = source.id
        self.elements = Array(elements)
    }

    init(id: FileListSectionID, elements: [FileListItem]) {
        self.id = id
        self.elements = elements
    }

    func isContentEqual(to source: FileListSection) -> Bool {
        id == source.id
    }
}
