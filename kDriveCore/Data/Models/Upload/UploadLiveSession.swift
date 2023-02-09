//
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

/// The object returned at the getSession call
public struct UploadLiveSession: Decodable {
    var expectedChunks: UInt64
    var receivedChunks: UInt64
    var uploadingChunks: UInt64
    var failedChunks: UInt64
    var expectedSize: UInt64
    var uploadedSize: UInt64
    
    private enum CodingKeys: String, CodingKey {
        case expectedChunks = "expected_chunks"
        case receivedChunks = "received_chunks"
        case uploadingChunks = "uploading_chunks"
        case failedChunks = "failed_chunks"
        case expectedSize = "expected_size"
        case uploadedSize = "uploaded_size"
    }
}
