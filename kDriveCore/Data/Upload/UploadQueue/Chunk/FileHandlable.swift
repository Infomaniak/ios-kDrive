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

/// Something that matches most of the FileHandle specification, used for testing
protocol FileHandlable {
    var availableData: Data { get }

    var description: String { get }

    func seek(toOffset offset: UInt64) throws

    func truncate(atOffset offset: UInt64) throws

    func synchronize() throws

    func close() throws

    func readToEnd() throws -> Data?

    func read(upToCount count: Int) throws -> Data?

    func offset() throws -> UInt64

    func seekToEnd() throws -> UInt64
}

/// Protocol conformance
extension FileHandle: FileHandlable {}
