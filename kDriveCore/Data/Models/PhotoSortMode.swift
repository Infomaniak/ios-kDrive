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
import kDriveResources

public enum PhotoSortMode: String, CaseIterable {
    case day, month, year

    public var title: String {
        switch self {
        case .day:
            return KDriveResourcesStrings.Localizable.sortDay
        case .month:
            return KDriveResourcesStrings.Localizable.sortMonth
        case .year:
            return KDriveResourcesStrings.Localizable.sortYear
        }
    }

    public var calendarComponents: Set<Calendar.Component> {
        switch self {
        case .day:
            return [.year, .month, .day]
        case .month:
            return [.year, .month]
        case .year:
            return [.year]
        }
    }

    public var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.formattingContext = .standalone
        switch self {
        case .day:
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .none
        case .month:
            dateFormatter.dateFormat = KDriveResourcesStrings.Localizable.photosHeaderDateFormat
        case .year:
            dateFormatter.dateFormat = "yyyy"
        }
        return dateFormatter
    }
}
