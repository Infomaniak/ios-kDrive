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
import kDriveCore
import Testing

@Suite("UTSearchLink")
struct UTSearchLink {
    @Test(
        "Parse all attributes from a search link",
        arguments: [(143_883, 1_754_949_600, 1_755_295_199, "searchQueryTest", ConvertedType.image, 6, "or")]
    )
    func parseSearchLink(
        driveId: Int,
        modifiedAfter: Int,
        modifiedBefore: Int,
        query: String,
        type: ConvertedType,
        categoryId: Int,
        categoryOperator: String
    ) async throws {
        let givenLink =
            "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/search?q=%7B%22modified_at%22%3A%22custom%22%2C%22modified_after%22%3A\(modifiedAfter)%2C%22modified_before%22%3A\(modifiedBefore)%2C%22kind%22%3A%22default%22%2C%22directory_id%22%3A1%2C%22query%22%3A%22\(query)%22%2C%22type%22%3A%22\(type)%22%2C%22category_ids%22%3A%5B\(categoryId)%5D%2C%22category_operator%22%3A%22\(categoryOperator)%22%7D"

        guard let url = URL(string: givenLink), let parsedResult = SearchLink(searchURL: url) else {
            Issue.record("Failed to parse the URL")
            return
        }

        #expect(parsedResult.searchURL == url)
        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.modifiedAfter == modifiedAfter)
        #expect(parsedResult.modifiedBefore == modifiedBefore)
        #expect(parsedResult.searchQuery == query)
        #expect(parsedResult.type == type)
        #expect(parsedResult.categoryIds == [categoryId])
        #expect(parsedResult.categoryOperator == categoryOperator)
    }

    @Test(
        "Fail to parse a non-valid search link",
        arguments: ["foo"], ["%7B%22kind%22%3A%22default%22%2C%22directory_id%22%3A1%2C%22query%22%3A%22testSearch%22%7D"]
    )
    func searchLinkInvalidURL(driveId: String, query: String) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/search?q=\(query)"

        guard let url = URL(string: givenLink) else {
            Issue.record("Failed to create URL")
            return
        }

        let parsedResult = SearchLink(searchURL: url)
        #expect(parsedResult == nil)
    }
}
