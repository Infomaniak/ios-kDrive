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
import kDriveCore

extension NSFileProviderPage {
    init(_ integer: Int) {
        self.init(withUnsafeBytes(of: integer.littleEndian) { Data($0) })
    }

    init?(_ cursor: FileCursor) {
        guard let cursorData = cursor.data(using: .utf8) else { return nil }
        self.init(cursorData)
    }

    var toCursor: FileCursor? {
        return String(data: rawValue, encoding: .utf8)
    }

    var toInt: Int {
        return rawValue.withUnsafeBytes { $0.load(as: Int.self) }.littleEndian
    }

    var isInitialPage: Bool {
        return self == NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage || self == NSFileProviderPage
            .initialPageSortedByName as NSFileProviderPage
    }
}
