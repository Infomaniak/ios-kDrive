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

import Combine
import Foundation

public class FileListOptions {
    public static let instance = FileListOptions()

    private init() {
        currentStyle = UserDefaults.shared.listStyle
        currentSortType = UserDefaults.shared.sortType
    }

    @Published public var currentStyle: ListStyle {
        didSet {
            UserDefaults.shared.listStyle = currentStyle
        }
    }

    @Published public var currentSortType: SortType {
        didSet {
            UserDefaults.shared.sortType = currentSortType
        }
    }
}
