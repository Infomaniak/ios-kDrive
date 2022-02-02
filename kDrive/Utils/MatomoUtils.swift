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
import kDriveCore

class MatomoUtils {
    static let shared = MatomoTracker(siteId: "8", baseURL: URL(string: "https://analytics.infomaniak.com/matomo.php")!)

    // Enable or disable Matomo tracking
    static let isEnabled = true

    enum EventCategory: String {
        case newElement, fileAction, fileInfo, shareAndRights, colorFolder, categories, search, fileList, comment, drive, account, settings, photoSync, home, inApp, trash, dropbox, mediaPlayer
    }

    enum UserAction: String {
        case click, input
    }

    private init() {
        MatomoUtils.connectUser()
    }

    static func connectUser() {
        shared.userId = String(AccountManager.instance.currentUserId)
    }

    static func track(view: [String]) {
        guard isEnabled else { return }
        shared.track(view: view)
    }

    static func track(eventWithCategory category: MatomoUtils.EventCategory, action: MatomoUtils.UserAction = .click, name: String, value: Float? = nil) {
        guard isEnabled else { return }
        shared.track(eventWithCategory: category.rawValue, action: action.rawValue, name: name, value: value)
    }

    static func track(eventWithCategory category: MatomoUtils.EventCategory, action: MatomoUtils.UserAction = .click, name: String, value: Bool) {
        track(eventWithCategory: category, action: action, name: name, value: value ? 1.0 : 0.0)
    }

    static func trackBulkEvent(eventWithCategory category: MatomoUtils.EventCategory, name: String, numberOfItems number: Int) {
        track(eventWithCategory: category, action: .click, name: "bulk\(number == 1 ? "Single" : "")\(name.capitalized)", value: Float(number))
    }

    static func trackDropBox(emailEnabled: Bool, passwordEnabled: Bool, dateEnabled: Bool, sizeEnabled: Bool, size: Int?) {
        track(eventWithCategory: .dropbox, name: "switchEmailOnFileImport", value: emailEnabled)
        track(eventWithCategory: .dropbox, name: "switchProtectWithPassword", value: passwordEnabled)
        track(eventWithCategory: .dropbox, name: "switchExpirationDate", value: dateEnabled)
        track(eventWithCategory: .dropbox, name: "switchLimitStorageSpace", value: sizeEnabled)
        if sizeEnabled, let size = size {
            MatomoUtils.track(eventWithCategory: .dropbox, name: "changeLimitStorage", value: Float(size))
        }
    }
}
