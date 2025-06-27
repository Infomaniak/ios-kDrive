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

import InfomaniakCoreCommonUI
import InfomaniakDI
import MatomoTracker
import SwiftUI

/// Deeplink entrypoint
public protocol DeeplinkParsable {
    /// Parse a deeplink and navigate to the desired location
    func parse(url: URL) async -> Bool
}

public struct DeeplinkParser: DeeplinkParsable {
    private enum DeeplinkPath: String {
        case store
        case file
    }

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var router: AppNavigable
    @LazyInjectService var sharedWithMeService: SharedWithMeServiceable

    public init() {
        // META: keep SonarCloud happy
    }

    public func parse(url: URL) async -> Bool {
        guard await !UniversalLinksHelper.handleURL(url) else {
            return true
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let params = components.queryItems else {
            if let sharedWithMeLink = await SharedWithMeLink(sharedWithMeURL: url) {
                await router.navigate(to: .sharedWithMe(sharedWithMeLink: sharedWithMeLink))
                return true

            } else {
                Log.sceneDelegate("Failed to open URL: Invalid URL", level: .error)
                return false
            }
        }

        if components.path == DeeplinkPath.store.rawValue,
           let userId = params.first(where: { $0.name == "userId" })?.value,
           let driveId = params.first(where: { $0.name == "driveId" })?.value,
           let driveIdInt = Int(driveId), let userIdInt = Int(userId) {
            await router.navigate(to: .store(driveId: driveIdInt, userId: userIdInt))
            matomo.track(eventWithCategory: .deeplink, name: DeeplinkPath.store.rawValue)
            return true

        } else if components.host == DeeplinkPath.file.rawValue {
            let files: [ImportedFile] = params.compactMap { param in
                guard param.name == "url", let filePath = param.value else { return nil }
                let fileUrl = URL(fileURLWithPath: filePath)

                return ImportedFile(name: fileUrl.lastPathComponent, path: fileUrl, uti: fileUrl.uti ?? .data)
            }
            guard !files.isEmpty else {
                Log.sceneDelegate("Failed to import files: No files found", level: .error)
                return false
            }
            await router.navigate(to: .saveFiles(files: files))
            matomo.track(eventWithCategory: .deeplink, name: DeeplinkPath.file.rawValue)
            return true
        }

        Log.sceneDelegate("unable to parse deeplink URL: \(url)", level: .error)
        return false
    }
}
