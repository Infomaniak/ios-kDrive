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

/// A mock of RangeProvidable
public final class MCKRangeProvidable: RangeProvidable {
    
    var allRangesCalled: Bool { allRangesCallCount > 0 }
    var allRangesCallCount: Int = 0
    var allRangesThrows: Error?
    var allRangesClosure: (()->[DataRange])?
    public var allRanges: [DataRange] {
        get throws {
            allRangesCallCount += 1
            if let allRangesThrows {
                throw allRangesThrows
            }
            else if let allRangesClosure {
                return allRangesClosure()
            }
            else {
                return []
            }
        }
     }
    
    public var fileSize: UInt64 = 0
}
