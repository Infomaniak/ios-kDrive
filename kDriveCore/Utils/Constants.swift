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
import InfomaniakCore
import kDriveResources
import UIKit

/// Represents the algorithm used to generate a diff of the image library
public enum PhotoLibraryImport: Int {
    /// The OG algorithm, based on filename comparison
    case legacyName = 0

    /// The incremental update of the algorithm, since iOS15, based on a hash.
    case hashBestResource = 1
}

public struct URLConstants {
    public static let kDriveRedirection = URLConstants(urlString: "https://kdrive.infomaniak.com/app/drive")
    public static let kDriveWeb = URLConstants(urlString: "https://kdrive.infomaniak.com")
    public static let signUp = URLConstants(urlString: "https://welcome.infomaniak.com/signup/ikdrive/steps")
    public static let shop = URLConstants(urlString: "https://shop.infomaniak.com/order/drive")
    public static let appStore = URLConstants(urlString: "https://apps.apple.com/app/infomaniak-kdrive/id1482778676")
    public static let testFlight = URLConstants(urlString: "https://testflight.apple.com/join/qZHSGy5B")
    public static let rgpd = URLConstants(urlString: "https://infomaniak.com/gtl/rgpd")
    public static let sourceCode = URLConstants(urlString: "https://github.com/Infomaniak/ios-kDrive")
    public static let gpl = URLConstants(urlString: "https://www.gnu.org/licenses/gpl-3.0.html")
    public static let support = URLConstants(urlString: "https://support.infomaniak.com")
    public static let faqIAP = URLConstants(urlString: "https://faq.infomaniak.com/2632")
    public static let matomo = URLConstants(urlString: "https://analytics.infomaniak.com/matomo.php")

    public static func renewDrive(accountId: Int) -> URLConstants {
        return URLConstants(urlString: "https://manager.infomaniak.com/v3/\(accountId)/accounts/accounting/renewal")
    }

    private var urlString: String

    public var url: URL {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL")
        }
        return url
    }
}

public enum Constants {
    public static let backgroundRefreshIdentifier = "com.infomaniak.background.refresh"
    public static let longBackgroundRefreshIdentifier = "com.infomaniak.background.long-refresh"

    public static let applicationShortcutScan = "com.infomaniak.shortcut.scan"
    public static let applicationShortcutSearch = "com.infomaniak.shortcut.search"
    public static let applicationShortcutUpload = "com.infomaniak.shortcut.upload"
    public static let applicationShortcutSupport = "com.infomaniak.shortcut.support"

    public static let notificationTopicUpload = "uploadTopic"
    public static let notificationTopicShared = "sharedTopic"
    public static let notificationTopicComments = "commentsTopic"
    public static let notificationTopicGeneral = "generalTopic"

    public static let mailRegex =
        "(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"

    public static let timeout: Double = 30
    public static let bulkActionThreshold = 10
    public static let activitiesReloadTimeOut: Double = 7_776_000 // 90 days

    /// Constants used by Kingfisher to manage image cache
    public enum ImageCache {
        public static let memorySizeLimit = 10 * 1024 * 1024 // 10 Mi
        public static let diskSizeLimit: UInt = 512 * 1024 * 1024 // 512 Mi
    }

    public static let kDriveTeams = "Solo, Team & Pro"

    private static var dateFormatter = DateFormatter()
    private static var fileSizeFormatter = MeasurementFormatter()

    public enum DateTimeStyle {
        case date
        case time
        case dateTime
    }

    public static func formatDate(_ date: Date, style: DateTimeStyle = .dateTime, relative: Bool = false) -> String {
        // Relative time
        let timeInterval = Date().timeIntervalSince(date)
        if relative && style != .date && timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            if minutes < 1 {
                return KDriveResourcesStrings.Localizable.allJustNow
            } else if minutes < 60 {
                return KDriveResourcesStrings.Localizable.allMinutesShort(minutes)
            }
        }

        switch style {
        case .date:
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
        case .time:
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short
        case .dateTime:
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
        }
        dateFormatter.doesRelativeDateFormatting = relative
        return dateFormatter.string(from: date)
    }

    public static func formatFileLastModifiedRelativeDate(_ lastModified: Date) -> String {
        if Date().timeIntervalSince(lastModified) < 3600 * 24 * 7 {
            let relativeDateFormatter = RelativeDateTimeFormatter()
            let timeInterval = lastModified.timeIntervalSinceNow < -1 ? lastModified.timeIntervalSinceNow : -1
            let relativeTime = relativeDateFormatter.localizedString(fromTimeInterval: timeInterval)
            return KDriveResourcesStrings.Localizable.allLastModifiedFileRelativeTime(relativeTime)
        }
        return formatFileLastModifiedDate(lastModified)
    }

    public static func formatFileLastModifiedDate(_ lastModified: Date) -> String {
        dateFormatter.dateFormat = KDriveResourcesStrings.Localizable.allLastModifiedFilePattern
        return dateFormatter.string(from: lastModified)
    }

    public static func formatFileDeletionRelativeDate(_ deletionDate: Date) -> String {
        if Date().timeIntervalSince(deletionDate) < 3600 * 24 * 7 {
            let relativeDateFormatter = RelativeDateTimeFormatter()
            let timeInterval = deletionDate.timeIntervalSinceNow < -1 ? deletionDate.timeIntervalSinceNow : -1
            let relativeTime = relativeDateFormatter.localizedString(fromTimeInterval: timeInterval)
            return KDriveResourcesStrings.Localizable.allDeletedFileRelativeTime(relativeTime)
        }
        return formatFileDeletionDate(deletionDate)
    }

    public static func formatFileDeletionDate(_ deletionDate: Date) -> String {
        dateFormatter.dateFormat = KDriveResourcesStrings.Localizable.allDeletedFilePattern
        return dateFormatter.string(from: deletionDate)
    }

    public static func formatFileSize(_ size: Int64, decimals: Int = 0, unit: Bool = true) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.countStyle = .binary
        byteCountFormatter.includesUnit = unit
        return byteCountFormatter.string(fromByteCount: size)
    }

    public static func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
        let calendar = Calendar.current
        let fromDate = calendar.startOfDay(for: from) // <1>
        let toDate = calendar.startOfDay(for: to) // <2>
        let numberOfDays = calendar.dateComponents([.day], from: fromDate, to: toDate) // <3>

        return numberOfDays.day!
    }

    public static func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    public static func appVersionLabel() -> String {
        return CorePlatform.appVersionLabel(fallbackAppName: "Mail")
    }

    public static let maxNetworkParallelism = 4
}

/// App lifecycle Constants
public enum AppDelegateConstants {
    /// Amount of time we can use max in `applicationWillTerminate`
    ///
    /// The documentation specifies `approximately five seconds [to] return` from applicationWillTerminate
    /// Therefore to not display a crash feedback on TestFlight, we give up after 4.5 seconds
    public static let closeApplicationGiveUpTime = 4.5
}
