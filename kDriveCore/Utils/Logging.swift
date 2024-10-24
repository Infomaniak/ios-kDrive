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
import InfomaniakDI
import InfomaniakLogin
import RealmSwift
import Sentry

public enum Logging {
    public static func initLogging() {
        // TODO: change
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        initLogger()
        initNetworkLogging()
        initSentry()
        copyDebugInformations()

        Log.appDelegate("initLogging done")
    }

    class LogFormatter: NSObject, DDLogFormatter {
        func format(message logMessage: DDLogMessage) -> String? {
            return "[Infomaniak] \(logMessage.message)"
        }
    }

    public static func reportRealmOpeningError(_ error: Error, realmConfiguration: Realm.Configuration) -> Never {
        let context = [
            "File URL": realmConfiguration.fileURL?.absoluteString ?? ""
        ]
        SentryDebug.capture(error: error, context: context, contextKey: "Realm")

        #if DEBUG
        copyDebugInformations()
        DDLogError(
            "Realm files \(realmConfiguration.fileURL?.lastPathComponent ?? "") will be deleted to prevent migration error for next launch"
        )
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
        let logFileManager = DDLogFileManagerDefault(logsDirectory: DriveFileManager.constants.cacheDirectoryURL
            .appendingPathComponent(
                "logs",
                isDirectory: true
            ).path)
        let fileLogger = DDFileLogger(logFileManager: logFileManager)
        // 24-hour rolling, 50 MB max per file, 7 files max.
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.maximumFileSize = 50 * 1024 * 1024
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)
    }

    private static func initNetworkLogging() {
        Atlantis.start(hostName: ProcessInfo.processInfo.environment["hostname"])
    }

    private static func initSentry() {
        SentrySDK.start { options in
            options.dsn = "https://ba647a8cc6fc437baf797d2eb33dfafb@sentry-mobile.infomaniak.com/6"
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
        @InjectService var appContextService: AppContextServiceable
        guard !appContextService.isExtension else {
            return
        }

        let fileManager = FileManager.default
        let debugDirectory = (fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(
            "debug",
            isDirectory: true
        ))!

        if !fileManager.fileExists(atPath: debugDirectory.path) {
            try? fileManager.createDirectory(atPath: debugDirectory.path, withIntermediateDirectories: true, attributes: nil)
        }

        do {
            let documentDrivesPath = debugDirectory.appendingPathComponent("drive", isDirectory: true).path
            let documentLogsPath = debugDirectory.appendingPathComponent("logs", isDirectory: true).path

            try? fileManager.removeItem(atPath: documentDrivesPath)
            try? fileManager.removeItem(atPath: documentLogsPath)

            if fileManager.fileExists(atPath: DriveFileManager.constants.realmRootURL.path) {
                try fileManager.copyItem(atPath: DriveFileManager.constants.realmRootURL.path, toPath: documentDrivesPath)
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
