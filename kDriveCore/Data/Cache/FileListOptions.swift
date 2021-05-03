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

public class FileListOptions {
    private var didChangeListStyleObservers = [UUID: (ListStyle) -> Void]()
    private var didChangeSortTypeObservers = [UUID: (SortType) -> Void]()

    public static let instance = FileListOptions()

    public var currentStyle: ListStyle {
        get {
            return UserDefaults.shared.listStyle
        }
        set {
            setStyle(newValue)
        }
    }

    public var currentSortType: SortType {
        get {
            return UserDefaults.shared.sortType
        }
        set {
            setSortType(newValue)
        }
    }

    private func setStyle(_ listStyle: ListStyle) {
        UserDefaults.shared.listStyle = listStyle

        didChangeListStyleObservers.values.forEach { closure in
            closure(listStyle)
        }
    }

    private func setSortType(_ sortType: SortType) {
        UserDefaults.shared.sortType = sortType

        didChangeSortTypeObservers.values.forEach { closure in
            closure(sortType)
        }
    }

}

// MARK: - Observation

extension FileListOptions {
    @discardableResult
    public func observeListStyleChange<T: AnyObject>(_ observer: T, using closure: @escaping (ListStyle) -> Void) -> ObservationToken {
        let key = UUID()
        didChangeListStyleObservers[key] = { [weak self, weak observer] style in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard let _ = observer else {
                self?.didChangeListStyleObservers.removeValue(forKey: key)
                return
            }

            closure(style)
        }

        return ObservationToken { [weak self] in
            self?.didChangeListStyleObservers.removeValue(forKey: key)
        }
    }

    @discardableResult
    public func observeSortTypeChange<T: AnyObject>(_ observer: T, using closure: @escaping (SortType) -> Void) -> ObservationToken {
        let key = UUID()
        didChangeSortTypeObservers[key] = { [weak self, weak observer] sortType in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard let _ = observer else {
                self?.didChangeSortTypeObservers.removeValue(forKey: key)
                return
            }

            closure(sortType)
        }

        return ObservationToken { [weak self] in
            self?.didChangeSortTypeObservers.removeValue(forKey: key)
        }
    }
}
