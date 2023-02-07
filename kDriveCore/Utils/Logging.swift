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

import Atlantis
import CocoaLumberjack
import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import InfomaniakLogin
import RealmSwift
import Sentry
import InfomaniakDI

public enum Logging {
    public static func initLogging() {
        UserDefaults.standard.set(true, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        initLogger()
        initNetworkLogging()
        initSentry()
        copyDebugInformations()
    }

    class LogFormatter: NSObject, DDLogFormatter {
        func format(message logMessage: DDLogMessage) -> String? {
            return "[Infomaniak] \(logMessage.message)"
        }
    }

    public static func reportRealmOpeningError(_ error: Error, realmConfiguration: Realm.Configuration) -> Never {
        SentrySDK.capture(error: error) { scope in
            scope.setContext(value: [
                "File URL": realmConfiguration.fileURL?.absoluteString ?? ""
            ], key: "Realm")
        }
        #if DEBUG
            copyDebugInformations()
            DDLogError("Realm files \(realmConfiguration.fileURL?.lastPathComponent ?? "") will be deleted to prevent migration error for next launch")
            _ = try? Realm.deleteFiles(for: realmConfiguration)
        #endif
        fatalError("Failed creating realm \(error.localizedDescription)")
    }

    public static func functionOverrideError(_ function: String) -> Never {
        fatalError(function + " needs to be overridden")
    }

    private static func initLogger() {
        DDOSLogger.sharedInstance.logFormatter = LogFormatter()
        DDLog.add(DDOSLogger.sharedInstance)
        let logFileManager = DDLogFileManagerDefault(logsDirectory: DriveFileManager.constants.cacheDirectoryURL.appendingPathComponent("logs", isDirectory: true).path)
        let fileLogger = DDFileLogger(logFileManager: logFileManager)
        fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)
    }

    private static func initNetworkLogging() {
        #if DEBUG
            if !Bundle.main.isExtension {
                // TODO: Remove
                Atlantis.start(hostName: "adrien-coye-mbp.local.")
//                Atlantis.start(hostName: ProcessInfo.processInfo.environment["hostname"])
            }
        #endif
    }

    private static func initSentry() {
        SentrySDK.start { options in
            options.dsn = "https://fb65d0bcbf4c4ce795a6e1c1a964da28@sentry.infomaniak.com/4"
            options.beforeSend = { event in
                // if the application is in debug mode discard the events
                event.context?["AppState"] = [
                    "AppLock enabled": UserDefaults.shared.isAppLockEnabled,
                    "Wifi only enabled": UserDefaults.shared.isWifiOnly
                ]
                #if DEBUG
                    return nil
                #else
                    return event
                #endif
            }
        }
    }

    private static func copyDebugInformations() {
        #if DEBUG
            guard !Bundle.main.isExtension else { return }
            let fileManager = FileManager.default
            let debugDirectory = (fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("debug", isDirectory: true))!

            if !fileManager.fileExists(atPath: debugDirectory.path) {
                try? fileManager.createDirectory(atPath: debugDirectory.path, withIntermediateDirectories: true, attributes: nil)
            }

            do {
                let documentDrivesPath = debugDirectory.appendingPathComponent("drive", isDirectory: true).path
                let documentLogsPath = debugDirectory.appendingPathComponent("logs", isDirectory: true).path

                try? fileManager.removeItem(atPath: documentDrivesPath)
                try? fileManager.removeItem(atPath: documentLogsPath)

                if fileManager.fileExists(atPath: DriveFileManager.constants.rootDocumentsURL.path) {
                    try fileManager.copyItem(atPath: DriveFileManager.constants.rootDocumentsURL.path, toPath: documentDrivesPath)
                }
                let cachedLogsUrl = DriveFileManager.constants.cacheDirectoryURL.appendingPathComponent("logs", isDirectory: true)
                if fileManager.fileExists(atPath: cachedLogsUrl.path) {
                    try fileManager.copyItem(atPath: cachedLogsUrl.path, toPath: documentLogsPath)
                }
            } catch {
                DDLogError("Failed to copy debug informations \(error)")
            }
        #endif
    }
}

// MARK: - Token logging

extension ApiToken {
    var truncatedAccessToken: String {
        truncateToken(accessToken)
    }

    var truncatedRefreshToken: String {
        truncateToken(refreshToken)
    }

    private func truncateToken(_ token: String) -> String {
        String(token.prefix(4) + "-*****-" + token.suffix(4))
    }

    func generateBreadcrumb(level: SentryLevel, message: String, keychainError: OSStatus = noErr) -> Breadcrumb {
        let crumb = Breadcrumb(level: level, category: "Token")
        crumb.type = level == .info ? "info" : "error"
        crumb.message = message
        crumb.data = ["User id": userId,
                      "Expiration date": expirationDate.timeIntervalSince1970,
                      "Access Token": truncatedAccessToken,
                      "Refresh Token": truncatedRefreshToken,
                      "Keychain error code": keychainError]
        return crumb
    }
}
