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

import InfomaniakDI
import SwiftUI

public struct DeeplinkParser {
    private enum DeeplinkPath: String {
        case store
        case file
    }

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var navigationManager: NavigationManageable

    public init() {
        // META: keep SonarCloud happy
    }

    public func parse(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let params = components.queryItems else {
            Log.appDelegate("Failed to open URL: Invalid URL", level: .error)
            return false
        }

        if components.path == DeeplinkPath.store.rawValue,
           let userId = params.first(where: { $0.name == "userId" })?.value,
           let driveId = params.first(where: { $0.name == "driveId" })?.value,
           let driveIdInt = Int(driveId), let userIdInt = Int(userId) {
            navigationManager.navigate(to: .store(driveId: driveIdInt, userId: userIdInt))
            return true

        } else if components.host == DeeplinkPath.file.rawValue,
                  let filePath = params.first(where: { $0.name == "url" })?.value {
            let fileUrl = URL(fileURLWithPath: filePath)
            let file = ImportedFile(name: fileUrl.lastPathComponent, path: fileUrl, uti: fileUrl.uti ?? .data)
            navigationManager.navigate(to: .saveFile(file: file))
            return true
        }

        Log.appDelegate("unable to parse deeplink URL: \(url)", level: .error)
        return false
    }
}
