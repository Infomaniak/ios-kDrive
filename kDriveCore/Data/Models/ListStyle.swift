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

import UIKit

public enum ListStyle: String {
    case list
    case grid

    public var icon: UIImage {
        switch self {
        case .list:
            return KDriveCoreAsset.list.image
        case .grid:
            return KDriveCoreAsset.grid.image
        }
    }
}

public class ListStyleManager {
    private var didChangeListStyleObservers = [UUID: (ListStyle) -> Void]()

    public static let instance = ListStyleManager()

    public var currentStyle: ListStyle {
        get {
            return UserDefaults.getListStyle()
        }
        set {
            setStyle(newValue)
        }
    }

    private func setStyle(_ listStyle: ListStyle) {
        UserDefaults.store(listStyle: listStyle)

        didChangeListStyleObservers.values.forEach { closure in
            closure(listStyle)
        }
    }

}

// MARK: - Observation

extension ListStyleManager {
    @discardableResult
    public func observeListStyleChange<T: AnyObject>(_ observer: T, using closure: @escaping (ListStyle) -> Void) -> ObservationToken {
        let key = UUID()
        didChangeListStyleObservers[key] = { [weak self, weak observer] status in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard let _ = observer else {
                self?.didChangeListStyleObservers.removeValue(forKey: key)
                return
            }

            closure(status)
        }

        return ObservationToken { [weak self] in
            self?.didChangeListStyleObservers.removeValue(forKey: key)
        }
    }
}
