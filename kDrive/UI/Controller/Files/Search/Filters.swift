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
import UIKit

protocol Filterable {
    var localizedName: String { get }
    var icon: UIImage { get }
}

extension DateInterval: Filterable {
    var localizedName: String {
        return "" // TODO: name
    }

    var icon: UIImage {
        return KDriveAsset.calendar.image
    }
}

extension ConvertedType: Filterable {
    var localizedName: String {
        return rawValue // TODO: name
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
    var date: DateInterval?
    var fileType: ConvertedType?
    var categories: Set<kDriveCore.Category> = []

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
    }
}
