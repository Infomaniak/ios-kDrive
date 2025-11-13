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

public struct SearchLink: Sendable, Equatable, LinkDriveProvider {
    public static let parsingRegex = Regex(pattern: #"^.*/app/drive/([0-9]+)/search.*$"#)

    public let searchURL: URL
    public let driveId: Int
    public let queryJson: String
    public let searchQuery: String
    public let type: ConvertedType?
    public let modifiedBefore: Int?
    public let modifiedAfter: Int?
    public let categoryIds: [Int]
    public let categoryOperator: String?

    public init?(searchURL: URL) {
        guard let components = URLComponents(url: searchURL, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let path = components.path
        guard let matches = Self.parsingRegex?.matches(in: path) else {
            return nil
        }

        guard let firstMatch = matches.first,
              let driveId = firstMatch[safe: 1],
              let driveIdInt = Int(driveId)
        else {
            return nil
        }

        guard let queryItem = components.queryItems?.first(where: { $0.name == "q" }),
              let queryJson = queryItem.value,
              let data = queryJson.data(using: .utf8),
              let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        self.searchURL = searchURL
        self.driveId = driveIdInt
        self.queryJson = queryJson
        searchQuery = jsonDict["query"] as? String ?? ""
        type = ConvertedType(apiRawValue: jsonDict["type"] as? String ?? "")
        modifiedBefore = jsonDict["modified_before"] as? Int
        modifiedAfter = jsonDict["modified_after"] as? Int
        categoryIds = jsonDict["category_ids"] as? [Int] ?? []
        categoryOperator = jsonDict["category_operator"] as? String
    }
}
