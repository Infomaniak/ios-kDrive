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

public struct URLConstants {
    public static let signUp = URLConstants(urlString: "https://welcome.infomaniak.com/signup/ikdrive/steps")
    public static let shop = URLConstants(urlString: "https://shop.infomaniak.com/order/drive")
    public static let appVersion = URLConstants(urlString: "https://itunes.apple.com/lookup?bundleId=com.infomaniak.drive")
    public static let appStore = URLConstants(urlString: "https://apps.apple.com/app/infomaniak-kdrive/id1482778676")
    public static let testFlight = URLConstants(urlString: "https://testflight.apple.com/join/qZHSGy5B")
    public static let rgpd = URLConstants(urlString: "https://infomaniak.com/gtl/rgpd")
    public static let sourceCode = URLConstants(urlString: "https://github.com/Infomaniak/ios-kDrive")
    public static let gpl = URLConstants(urlString: "https://www.gnu.org/licenses/gpl-3.0.html")
    public static let support = URLConstants(urlString: "https://support.infomaniak.com")
    public static let faqIAP = URLConstants(urlString: "https://faq.infomaniak.com/2631")

    private var urlString: String

    public var url: URL {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL")
        }
        return url
    }
}

public enum Constants {
    public static let isInExtension: Bool = {
        let bundleUrl: URL = Bundle.main.bundleURL
        let bundlePathExtension: String = bundleUrl.pathExtension
        return bundlePathExtension == "appex"
    }()

    public static let backgroundRefreshIdentifier = "com.infomaniak.background.refresh"
    public static let longBackgroundRefreshIdentifier = "com.infomaniak.background.long-refresh"

    public static let notificationTopicUpload = "uploadTopic"
    public static let notificationTopicShared = "sharedTopic"
    public static let notificationTopicComments = "commentsTopic"
    public static let notificationTopicGeneral = "generalTopic"

    public static let mailRegex = "(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"

    public static let timeout: Double = 30
    public static let bulkActionThreshold = 10

    private static var dateFormatter = DateFormatter()
    private static var fileSizeFormatter = MeasurementFormatter()

    public enum DateTimeStyle {
        case date
        case time
        case datetime
    }

    public static func formatDate(_ date: Date, style: DateTimeStyle = .datetime, relative: Bool = false) -> String {
        // Relative time
        let timeInterval = Date().timeIntervalSince(date)
        if relative && style != .date && timeInterval < 3_600 {
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
        case .datetime:
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
        }
        dateFormatter.doesRelativeDateFormatting = relative
        return dateFormatter.string(from: date)
    }

    public static func formatTimestamp(_ timeInterval: TimeInterval, style: DateTimeStyle = .datetime, relative: Bool = false) -> String {
        return formatDate(Date(timeIntervalSince1970: timeInterval), style: style, relative: relative)
    }

    public static func formatFileLastModifiedRelativeDate(_ lastModified: Date) -> String {
        if Date().timeIntervalSince(lastModified) < 3_600 * 24 * 7 {
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
        if Date().timeIntervalSince(deletionDate) < 3_600 * 24 * 7 {
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
}
