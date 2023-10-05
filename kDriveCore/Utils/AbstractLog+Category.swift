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

        SentryDebug.loggerBreadcrumb(caller: "\(function)", category: category, isError: level == .error)

        ABLog(message(),
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

        SentryDebug.loggerBreadcrumb(caller: "\(function)", category: category, isError: level == .error)

        ABLog(message(),
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

        ABLog(message(),
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
    public static func bgTaskScheduling(_ message: @autoclosure () -> Any,
                                        level: AbstractLogLevel = .debug,
                                        context: Int = 0,
                                        file: StaticString = #file,
                                        function: StaticString = #function,
                                        line: UInt = #line,
                                        tag: Any? = nil) {
        let category = "BGTaskScheduling"

        SentryDebug.loggerBreadcrumb(caller: "\(function)", category: category, isError: level == .error)

        ABLog(message(),
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

        SentryDebug.loggerBreadcrumb(caller: "\(function)", category: category, isError: level == .error)

        ABLog(message(),
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

        SentryDebug.loggerBreadcrumb(caller: "\(function)", category: category, isError: level == .error)

        ABLog(message(),
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
            SentryDebug.loggerBreadcrumb(caller: "\(function)", category: category, metadata: ["message": messageString])
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
}
