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
import InfomaniakCore

public extension RangeProvider {
    /// Encapsulating API parameters used to compute ranges
    enum APIConstants {
        static let smallFileMaxSize: UInt64 = 5 * 1024 * 1024
    }

    static var kDriveConfig: RangeProvider.Config {
        RangeProvider.Config(chunkMinSize: 1 * 1024 * 1024,
                             chunkMaxSizeClient: 50 * 1024 * 1024,
                             chunkMaxSizeServer: 1 * 1024 * 1024 * 1024,
                             optimalChunkCount: 200,
                             maxTotalChunks: 10000,
                             minTotalChunks: 1)
    }
}
