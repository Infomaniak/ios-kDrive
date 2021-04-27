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

public class DropBox: Codable {
    public var id: Int
    public var alias: String
    public var emailWhenFinished: Bool
    public var limitFileSize: Int?
    public var password: Bool
    public var url: String
    public var validUntil: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case alias
        case emailWhenFinished = "email_when_finished"
        case limitFileSize = "limit_file_size"
        case password
        case url
        case validUntil = "valid_until"
    }
}
