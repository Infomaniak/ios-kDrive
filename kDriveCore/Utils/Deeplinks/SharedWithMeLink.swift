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

public struct SharedWithMeLink: Sendable {
    public static let validationRegex =
        Regex(pattern: #"^/all/kdrive/app/drive/([0-9]+)/shared-with-me(?:/.*)?$"#)

    public let sharedWithMeURL: URL
    public let driveId: Int
    public let sharedDriveId: Int?
    public let folderId: Int?
    public let fileId: Int?

    public init?(sharedWithMeURL: URL) async {
        guard let components = URLComponents(url: sharedWithMeURL, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let path = components.path
        guard let matches = Self.validationRegex?.matches(in: path) else {
            return nil
        }

        guard let mandatoryMatch = matches.first,
              let driveId = mandatoryMatch[safe: 1],
              let driveIdInt = Int(driveId) else {
            return nil
        }

        let baseUrl = "/all/kdrive/app/drive/\(driveId)/shared-with-me"
        let tail = path.replacingOccurrences(of: baseUrl, with: "")
        let parameters = tail.split(separator: "/").map { String($0) }

        sharedDriveId = Int(parameters[safe: 0] ?? "")
        folderId = Int(parameters[safe: 1] ?? "")
        fileId = Int(parameters[safe: 4] ?? "")
        self.driveId = driveIdInt
        self.sharedWithMeURL = sharedWithMeURL
    }
}
