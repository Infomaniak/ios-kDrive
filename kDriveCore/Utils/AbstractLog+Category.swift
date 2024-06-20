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

import Foundation
import InfomaniakLogin

/// Name spacing log methods by `category`.
public enum Log {
    /// shorthand for ABLog, with "FileProvider" category
    ///
    /// In system console, visualize them with `subsystem:com.infomaniak.drive category:FileProvider`
    ///
    public static func fileProvider(_ message: @autoclosure () -> Any,
                                    level: AbstractLogLevel = .debug,
                                    context: Int = 0,
                                    file: StaticString = #file,
                                    function: StaticString = #function,
                                    line: UInt = #line,
                                    tag: Any? = nil) {
        let category = "FileProvider"
        defaultLogHandler(message(),
                          category: category,
                          level: level,
                          context: context,
                          file: file,
                          function: function,
                          line: line,
                          tag: tag)
    }

    /// shorthand for ABLog, with "AppDelegate" category
    ///
    /// In system console, visualize them with `subsystem:com.infomaniak.drive category:AppDelegate`
    ///
    public static func appDelegate(_ message: @autoclosure () -> Any,
                                   level: AbstractLogLevel = .debug,
                                   context: Int = 0,
                                   file: StaticString = #file,
                                   function: StaticString = #function,
                                   line: UInt = #line,
                                   tag: Any? = nil) {
        let category = "AppDelegate"
        defaultLogHandler(message(),
                          category: category,
                          level: level,
                          context: context,
                          file: file,
                          function: function,
                          line: line,
                          tag: tag)
    }

    /// shorthand for ABLog, with "PhotoLibraryUploader" category
    ///
    /// In system console, visualize them with `subsystem:com.infomaniak.drive category:PhotoLibraryUploader`
    ///
    public static func photoLibraryUploader(_ message: @autoclosure () -> Any,
                                            level: AbstractLogLevel = .debug,
                                            context: Int = 0,
                                            file: StaticString = #file,
                                            function: StaticString = #function,
                                            line: UInt = #line,
                                            tag: Any? = nil) {
        let category = "PhotoLibraryUploader"
        defaultLogHandler(message(),
                          category: category,
                          level: level,
                          context: context,
                          file: file,
                          function: function,
                          line: line,
                          tag: tag)
    }

    /// shorthand for ABLog, with "BGTaskScheduling" category
    ///
    /// In system console, visualize them with `subsystem:com.infomaniak.drive category:BGTaskScheduling`
    ///
    public static func backgroundTaskScheduling(_ message: @autoclosure () -> Any,
                                                level: AbstractLogLevel = .debug,
                                                context: Int = 0,
                                                file: StaticString = #file,
                                                function: StaticString = #function,
                                                line: UInt = #line,
                                                tag: Any? = nil) {
        let category = "BGTaskScheduling"
        defaultLogHandler(message(),
                          category: category,
                          level: level,
                          context: context,
                          file: file,
                          function: function,
                          line: line,
                          tag: tag)
    }

    /// shorthand for ABLog, with "BackgroundSessionManager" category
    ///
    /// In system console, visualize them with `subsystem:com.infomaniak.drive category:BackgroundSessionManager`
    ///
    public static func bgSessionManager(_ message: @autoclosure () -> Any,
                                        level: AbstractLogLevel = .debug,
                                        context: Int = 0,
                                        file: StaticString = #file,
                                        function: StaticString = #function,
                                        line: UInt = #line,
                                        tag: Any? = nil) {
        let category = "BackgroundSessionManager"
        defaultLogHandler(message(),
                          category: category,
                          level: level,
                          context: context,
                          file: file,
                          function: function,
                          line: line,
                          tag: tag)
    }

    /// shorthand for ABLog, with "UploadQueue" category
    public static func uploadQueue(_ message: @autoclosure () -> Any,
                                   level: AbstractLogLevel = .debug,
                                   context: Int = 0,
                                   file: StaticString = #file,
                                   function: StaticString = #function,
                                   line: UInt = #line,
                                   tag: Any? = nil) {
        let category = "UploadQueue"
        defaultLogHandler(message(),
                          category: category,
                          level: level,
                          context: context,
                          file: file,
                          function: function,
                          line: line,
                          tag: tag)
    }

    /// shorthand for ABLog, with "UploadOperation" category
    public static func uploadOperation(_ message: @autoclosure () -> Any,
                                       level: AbstractLogLevel = .debug,
                                       context: Int = 0,
                                       file: StaticString = #file,
                                       function: StaticString = #function,
                                       line: UInt = #line,
                                       tag: Any? = nil) {
        let category = "UploadOperation"
        let messageString = message()

        if level == .error {
            // Add a breadcrumb only for .errors only
            SentryDebug.loggerBreadcrumb(caller: "\(function)", metadata: ["message": messageString])
        }

        ABLog(messageString,
              category: category,
              level: level,
              context: context,
              file: file,
              function: function,
              line: line,
              tag: tag)
    }

    /// Shorthand for ABLog, with "DriveInfosManager" category.
    ///
    /// Sentry tracking enabled when level == .error
    public static func driveInfosManager(_ message: @autoclosure () -> Any,
                                         level: AbstractLogLevel = .debug,
                                         context: Int = 0,
                                         file: StaticString = #file,
                                         function: StaticString = #function,
                                         line: UInt = #line,
                                         tag: Any? = nil) {
        let category = "DriveInfosManager"
        let messageAny = message()
        guard let messageString = messageAny as? String else {
            assertionFailure("This should always cast to a String")
            return
        }

        // All errors are tracked on Sentry
        if level == .error {
            SentryDebug.addBreadcrumb(message: messageString, category: .DriveInfosManager, level: .error)
            SentryDebug.capture(message: messageString, level: .error, extras: ["function": "\(function)", "line": "\(line)"])
        }

        ABLog(messageAny,
              category: category,
              level: level,
              context: context,
              file: file,
              function: function,
              line: line,
              tag: tag)
    }

    public static func tokenAuthentication(_ message: @autoclosure () -> Any,
                                           oldToken: ApiToken?,
                                           newToken: ApiToken?,
                                           level: AbstractLogLevel = .debug,
                                           file: StaticString = #file,
                                           function: StaticString = #function,
                                           line: UInt = #line,
                                           tag: Any? = nil) {
        let category = "SyncedAuthenticator"
        let messageAny = message()
        guard let messageString = messageAny as? String else {
            assertionFailure("This should always cast to a String")
            return
        }

        let oldTokenMetadata: Any = oldToken?.metadata ?? "NULL"
        let newTokenMetadata: Any = newToken?.metadata ?? "NULL"
        var metadata = [String: Any]()
        metadata["oldToken"] = oldTokenMetadata
        metadata["newToken"] = newTokenMetadata

        SentryDebug.capture(
            message: messageString,
            context: metadata,
            level: level.sentry,
            extras: ["file": "\(file)", "function": "\(function)", "line": "\(line)"]
        )

        SentryDebug.addBreadcrumb(message: messageString, category: .DriveInfosManager, level: level.sentry, metadata: metadata)

        ABLog(messageAny,
              category: category,
              level: level,
              file: file,
              function: function,
              line: line,
              tag: tag)

        // log token if error state
        if level == .error || level == .fault {
            let tokenMessage = "old token:\(oldTokenMetadata) \nnew token:\(newTokenMetadata)"
            ABLog(tokenMessage,
                  category: category,
                  level: level,
                  file: file,
                  function: function,
                  line: line,
                  tag: tag)
        }
    }

    private static func defaultLogHandler(_ message: @autoclosure () -> Any,
                                          category: String,
                                          level: AbstractLogLevel,
                                          context: Int,
                                          file: StaticString,
                                          function: StaticString,
                                          line: UInt,
                                          tag: Any?) {
        let messageString = message()

        SentryDebug.loggerBreadcrumb(
            caller: "\(function)",
            metadata: ["message": messageString],
            isError: level == .error
        )

        ABLog(messageString,
              category: category,
              level: level,
              context: context,
              file: file,
              function: function,
              line: line,
              tag: tag)
    }
}
