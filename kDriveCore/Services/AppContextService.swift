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

/// All the ways some code can be executed within the __kDrive__ project
public enum DriveAppContext: String {
    /// Current execution context is the main app
    case app

    /// Current execution context is testing
    case appTests

    /// Current execution context is an action extension
    case actionExtension

    /// Current execution context is the file provider extension
    case fileProviderExtension

    /// Current execution context is the share extension
    case shareExtension
}

/// Something that can provide the active execution context
public protocol AppContextServiceable {
    /// Get the current execution context
    var context: DriveAppContext { get }

    /// Shorthand to check if we are within the main app or any extension
    var isExtension: Bool { get }
}

public struct AppContextService: AppContextServiceable {
    public var context: DriveAppContext

    public var isExtension: Bool {
        guard context == .app, context == .appTests else {
            return true
        }

        return false
    }

    public init(context: DriveAppContext) {
        self.context = context
    }
}
