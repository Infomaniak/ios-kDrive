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
import MatomoTracker

class MatomoUtils {
    static let shared = MatomoTracker(siteId: "8", baseURL: URL(string: "https://analytics.infomaniak.com/matomo.php")!)

    enum EventCategory: String {
        case newElement, offline, favorite, colorFolder, categories, search, fileList, comment, drive, account, settings, home
    }

    enum UserAction: String {
        case click
    }

    static func track(view: [String]) {
        shared.track(view: view)
    }

    static func track(eventWithCategory category: MatomoUtils.EventCategory, action: MatomoUtils.UserAction = .click, name: String? = nil, value: Float? = nil) {
        shared.track(eventWithCategory: category.rawValue, action: action.rawValue, name: name, value: value)
    }

    static func track(eventWithCategory category: MatomoUtils.EventCategory, action: MatomoUtils.UserAction = .click, name: String? = nil, value: Bool) {
        track(eventWithCategory: category, action: action, name: name, value: value ? 1 : 0)
    }
}
