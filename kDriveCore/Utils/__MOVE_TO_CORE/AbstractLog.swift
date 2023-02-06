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

import CocoaLumberjackSwift
import Foundation

public enum AbstractLogLevel {
    case emergency
    case alert
    case critical
    case error
    case warning
    case notice
    case info
    case debug
}


/// Simple abstract log mechanism, wrapping cocoalumberjack
/// - Parameters:
///   - message: the message we want to log
///   - level: the log level
///   - context: the context
///   - file: the file name this event originates from
///   - function: the function name this event originates from
///   - line: the line this event originates from
///   - tag: any extra info
///   - async: Should this be async?
@inlinable public func ABLog(_ message: @autoclosure () -> Any,
                             level: AbstractLogLevel = .info,
                             context: Int = 0,
                             file: StaticString = #file,
                             function: StaticString = #function,
                             line: UInt = #line,
                             tag: Any? = nil,
                             asynchronous async: Bool = asyncLoggingEnabled) {
    #if DEBUG
    // Forward to cocoaLumberjack
    switch level {
    case .error:
        DDLogError(message(),
                   context: context,
                   file: file,
                   function: function,
                   line: line,
                   tag: tag,
                   asynchronous: async,
                   ddlog: .sharedInstance)
    case.info: fallthrough
    default:
        DDLogInfo(message(),
                  context: context,
                  file: file,
                  function: function,
                  line: line,
                  tag: tag,
                  asynchronous: async,
                  ddlog: .sharedInstance)
    }
    
    #endif
}
