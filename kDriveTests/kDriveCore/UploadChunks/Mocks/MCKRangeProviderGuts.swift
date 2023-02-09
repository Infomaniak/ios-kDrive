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

import kDriveCore

/// A manualy written mock of the RangeProviderGutsable protocol
final class MCKRangeProviderGutsable: RangeProviderGutsable {
    var buildRangesCalled: Bool = false
    var buildRangesReturnValue: [DataRange] = []
    func buildRanges(fileSize: UInt64, totalChunksCount: UInt64, chunkSize: UInt64) -> [DataRange] {
        buildRangesCalled = true
        return buildRangesReturnValue
    }
    
    var readFileByteSizeCalled: Bool = false
    var readFileByteSizeReturnValue: UInt64 = 0
    func readFileByteSize() throws -> UInt64 {
        readFileByteSizeCalled = true
        return readFileByteSizeReturnValue
    }
    
    var preferedChunkSizeCalled: Bool = false
    var preferedChunkSizeReturnValue: UInt64 = 0
    func preferedChunkSize(for fileSize: UInt64) -> UInt64 {
        preferedChunkSizeCalled = true
        return preferedChunkSizeReturnValue
    }
}
