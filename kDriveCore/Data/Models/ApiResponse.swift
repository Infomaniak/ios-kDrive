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
import InfomaniakCore

public enum ApiResult: String, Codable {
    case success
    case error
}

public class EmptyResponse: Codable {}

public class CancelableResponse: Codable {
    public let id: String
    public let validUntil: Int
    public var offline: Bool {
        return id.isEmpty
    }

    init() {
        id = ""
        validUntil = 0
    }

    enum CodingKeys: String, CodingKey {
        case id = "cancel_id"
        case validUntil = "cancel_valid_until"
    }
}

public class ApiResponse<ResponseContent: Codable>: Codable {
    public let result: ApiResult
    public let data: ResponseContent?
    public let error: ApiError?
    public let total: Int?
    public let pages: Int?
    public let page: Int?
    public let itemsPerPage: Int?
    public let responseAt: Int?

    enum CodingKeys: String, CodingKey {
        case result
        case data
        case error
        case total
        case pages
        case page
        case itemsPerPage = "items_per_page"
        case responseAt = "response_at"
    }
}
