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
    private var didChangeListStyleObservers = [UUID: (ListStyle) -> Void]()

    public static let instance = FileListOptions()

    private init() {
        currentSortType = UserDefaults.shared.sortType
    }

    public var currentStyle: ListStyle {
        get {
            return UserDefaults.shared.listStyle
        }
        set {
            setStyle(newValue)
        }
    }

    @Published public var currentSortType: SortType {
        didSet {
            UserDefaults.shared.sortType = currentSortType
        }
    }

    private func setStyle(_ listStyle: ListStyle) {
        UserDefaults.shared.listStyle = listStyle

        didChangeListStyleObservers.values.forEach { closure in
            closure(listStyle)
        }
    }
}

// MARK: - Observation

public extension FileListOptions {
    @discardableResult
    func observeListStyleChange<T: AnyObject>(_ observer: T, using closure: @escaping (ListStyle) -> Void) -> ObservationToken {
        let key = UUID()
        didChangeListStyleObservers[key] = { [weak self, weak observer] style in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.didChangeListStyleObservers.removeValue(forKey: key)
                return
            }

            closure(style)
        }

        return ObservationToken { [weak self] in
            self?.didChangeListStyleObservers.removeValue(forKey: key)
        }
    }
}
