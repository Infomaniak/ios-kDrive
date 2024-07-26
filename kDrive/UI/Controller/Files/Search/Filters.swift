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

import kDriveCore
import kDriveResources
import UIKit

protocol Filterable {
    var localizedName: String { get }
    var icon: UIImage { get }
}

enum DateOption: Filterable, Selectable, Equatable {
    case today
    case yesterday
    case last7days
    case custom(DateInterval)

    var localizedName: String {
        switch self {
        case .today:
            return KDriveResourcesStrings.Localizable.allToday
        case .yesterday:
            return KDriveResourcesStrings.Localizable.allYesterday
        case .last7days, .custom:
            let dateIntervalFormatter = DateIntervalFormatter()
            dateIntervalFormatter.dateStyle = .medium
            dateIntervalFormatter.timeStyle = .none
            return dateIntervalFormatter.string(from: dateInterval) ?? ""
        }
    }

    var icon: UIImage {
        return KDriveResourcesAsset.calendar.image
    }

    var title: String {
        switch self {
        case .today:
            return KDriveResourcesStrings.Localizable.allToday
        case .yesterday:
            return KDriveResourcesStrings.Localizable.allYesterday
        case .last7days:
            return KDriveResourcesStrings.Localizable.allLast7Days
        case .custom:
            return KDriveResourcesStrings.Localizable.allDateCustom
        }
    }

    var dateInterval: DateInterval {
        switch self {
        case .today:
            let todayStart = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
            let todayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
            return DateInterval(start: todayStart, end: todayEnd)
        case .yesterday:
            let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let yesterdayStart = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: oneDayAgo)!
            let yesterdayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: oneDayAgo)!
            return DateInterval(start: yesterdayStart, end: yesterdayEnd)
        case .last7days:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
            let sevenDaysStart = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: sevenDaysAgo)!
            let sevenDaysEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
            return DateInterval(start: sevenDaysStart, end: sevenDaysEnd)
        case .custom(let dateInterval):
            return dateInterval
        }
    }
}

extension ConvertedType: Filterable {
    var localizedName: String {
        return title
    }
}

extension kDriveCore.Category: Filterable {
    var icon: UIImage {
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color?.setFill()
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            ctx.cgContext.fillEllipse(in: rect)
        }
    }
}

struct Filters {
    var date: DateOption?
    var fileType: ConvertedType?
    var categories: Set<kDriveCore.Category> = []
    var belongToAllCategories = true

    var fileExtensionsRaw: String?

    private static var splitCharacterSet = CharacterSet(charactersIn: ", ")
    var fileExtensions: [String] {
        guard let fileExtensionsRaw else {
            return []
        }

        let components = fileExtensionsRaw
            .components(separatedBy: Self.splitCharacterSet)
            .filter { !$0.isEmpty }

        return components
    }

    var hasFilters: Bool {
        return date != nil || fileType != nil || !categories.isEmpty
    }

    var asCollection: [Filterable] {
        let collection: [Filterable?] = [date, fileType]
        return collection.compactMap { $0 } + Array(categories)
    }

    mutating func clearFilters() {
        date = nil
        fileType = nil
        categories.removeAll()
        fileExtensionsRaw = nil
    }
}
