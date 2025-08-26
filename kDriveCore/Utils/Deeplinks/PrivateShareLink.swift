/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import SwiftRegex

public struct PrivateShareLink: Sendable, Equatable {
    public static let parsingRegex = Regex(pattern: #"^.*/app/drive/([0-9]+)/redirect/([0-9]+)$"#)

    public let privateShareUrl: URL
    public let driveId: Int
    public let fileId: Int

    public init?(privateShareUrl: URL) {
        guard let components = URLComponents(url: privateShareUrl, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let path = components.path
        guard let matches = Self.parsingRegex?.matches(in: path) else {
            return nil
        }

        guard let firstMatch = matches.first,
              let driveId = firstMatch[safe: 1],
              let driveIdInt = Int(driveId),
              let fileId = firstMatch[safe: 2],
              let fileIdInt = Int(fileId)
        else {
            return nil
        }

        self.privateShareUrl = privateShareUrl
        self.driveId = driveIdInt
        self.fileId = fileIdInt
    }
}
