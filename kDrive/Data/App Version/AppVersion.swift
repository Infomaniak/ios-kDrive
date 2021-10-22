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

struct Response: Codable {
    var results: [AppVersion]
}

struct AppVersion: Codable {
    var version: String?
    var currentVersionReleaseDate: String?

    private enum CodingKeys: String, CodingKey {
        case version
        case currentVersionReleaseDate
    }

    func loadVersionData(handler: @escaping (_ resultList: AppVersion) -> Void) {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=com.infomaniak.drive") else {
            return
        }

        let request = URLRequest(url: url)

        URLSession.shared.dataTask(with: request) { data, _, error in

            if let data = data {
                if let decodedResponse = try? JSONDecoder().decode(Response.self, from: data) {
                    DispatchQueue.main.async {
                        handler(decodedResponse.results[0])
                    }
                    return
                }
            }

            print("Error: \(error?.localizedDescription ?? "Unknown error")")
            // Handle error

        }.resume()
    }

    func showUpdateFloatingPanel() -> Bool {
        // Check and store the current App Store version.
        guard let currentAppStoreVersion = version else {
            return false
        }
        // Check if the App Store version is newer than the currently installed version.
        let currentInstalledVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        guard DataParser.isAppStoreVersionNewer(installedVersion: currentInstalledVersion, appStoreVersion: currentAppStoreVersion) else {
            return false
        }

        // Check the release date of the current version.
        guard let currentVersionReleaseDate = currentVersionReleaseDate, let daysSinceRelease = Date.days(since: currentVersionReleaseDate) else {
            return false
        }

        // Check if application has been released for 1 day.
        return daysSinceRelease >= 1
    }

    static func showUpdateFloatingPanel() -> Bool {
        var showUpdateFloatingPanel = false
        let group = DispatchGroup()
        group.enter()
        AppVersion().loadVersionData { appVersion in
            showUpdateFloatingPanel = appVersion.showUpdateFloatingPanel()
            group.leave()
        }
        return showUpdateFloatingPanel
    }
}
