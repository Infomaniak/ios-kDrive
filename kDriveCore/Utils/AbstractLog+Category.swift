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

// MARK: - Log methods, by "category"

/// shorthand for ABLog, with "BackgroundSessionManager" category
public func BackgroundSessionManagerLog(_ message: @autoclosure () -> Any,
                                        level: AbstractLogLevel = .info,
                                        context: Int = 0,
                                        file: StaticString = #file,
                                        function: StaticString = #function,
                                        line: UInt = #line,
                                        tag: Any? = nil) {
    let category = "BackgroundSessionManager"
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
public func UploadQueueLog(_ message: @autoclosure () -> Any,
                           level: AbstractLogLevel = .info,
                           context: Int = 0,
                           file: StaticString = #file,
                           function: StaticString = #function,
                           line: UInt = #line,
                           tag: Any? = nil) {
    let category = "UploadQueue"
    ABLog(message(),
          category: category,
          level: level,
          context: context,
          file: file,
          function: function,
          line: line,
          tag: tag)
}

// MARK: Operations

/// shorthand for ABLog, with "UploadOperation" category
public func UploadOperationLog(_ message: @autoclosure () -> Any,
                               level: AbstractLogLevel = .info,
                               context: Int = 0,
                               file: StaticString = #file,
                               function: StaticString = #function,
                               line: UInt = #line,
                               tag: Any? = nil) {
    let category = "UploadOperation"
    ABLog(message(),
          category: category,
          level: level,
          context: context,
          file: file,
          function: function,
          line: line,
          tag: tag)
}

/// shorthand for ABLog, with "CloseUploadSessionOperation" category
public func CloseUploadSessionOperationLog(_ message: @autoclosure () -> Any,
                                           level: AbstractLogLevel = .info,
                                           context: Int = 0,
                                           file: StaticString = #file,
                                           function: StaticString = #function,
                                           line: UInt = #line,
                                           tag: Any? = nil) {
    let category = "CloseUploadSessionOperation"
    ABLog(message(),
          category: category,
          level: level,
          context: context,
          file: file,
          function: function,
          line: line,
          tag: tag)
}

