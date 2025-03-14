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

/// Something that builds chunks and provide them with an iterator.
public protocol ChunkProvidable: IteratorProtocol {
    init?(fileURL: URL, ranges: [DataRange])
}

/// Something that can chunk a file part by part, in memory, given specified ranges.
///
/// Memory considerations: Max memory use ≈sizeOf(one chunk). So from 1Mb to 50Mb
/// Thread safety: Not thread safe
///
public final class ChunkProvider: ChunkProvidable {
    public typealias Element = Data

    let fileHandle: FileHandlable

    var ranges: [DataRange]

    deinit {
        do {
            // For the sake of consistency
            try fileHandle.close()
        } catch {}
    }

    public init?(fileURL: URL, ranges: [DataRange]) {
        self.ranges = ranges

        do {
            fileHandle = try FileHandle(forReadingFrom: fileURL)
        } catch {
            return nil
        }
    }

    /// Internal testing method
    init(mockedHandlable: FileHandlable, ranges: [DataRange]) {
        self.ranges = ranges
        fileHandle = mockedHandlable
    }

    /// Will provide chunks one by one, using the IteratorProtocol
    /// Starting by the first range available.
    public func next() -> Data? {
        guard !ranges.isEmpty else {
            return nil
        }

        let range = ranges.removeFirst()

        do {
            let chunk = try readChunk(range: range)
            return chunk
        } catch {
            return nil
        }
    }

    // MARK: Internal

    func readChunk(range: DataRange) throws -> Data? {
        let offset = range.lowerBound
        try fileHandle.seek(toOffset: offset)

        let byteCount = Int(range.upperBound - range.lowerBound) + 1
        let chunk = try fileHandle.read(upToCount: byteCount)
        return chunk
    }
}

/// Print the FileHandle shows the current offset
extension FileHandle {
    override open var description: String {
        let superDescription = super.description

        let offsetString: String
        do {
            let offset = try offset()
            offsetString = "\(offset)"
        } catch {
            offsetString = "\(error)"
        }

        let buffer = """
        <\(superDescription)>
        <offset:\(offsetString)>
        """

        return buffer
    }
}
