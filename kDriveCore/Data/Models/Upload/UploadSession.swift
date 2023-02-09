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

public struct UploadSession: Decodable {
    public var directoryId: UInt64?
    
    public var directoryPath: String?
    
    public var file: File?
    
    public var fileName: String?
    
    public var message: String?
    
    public var result: Bool?
    
    public var token: UploadSessionToken?
    
    enum CodingKeys: String, CodingKey {
        case directoryId = "directory_id"
        case directoryPath = "directory_path"
        case file
        case fileName = "file_name"
        case message
        case result
        case token
    }
}
