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

/// Interface of FileManager used for testing.
public protocol FileManagerable {
    // MARK: peer into the abyss 👀

    func fileExists(atPath path: String) -> Bool
    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool
    func isReadableFile(atPath path: String) -> Bool
    func isWritableFile(atPath path: String) -> Bool
    func isExecutableFile(atPath path: String) -> Bool
    func isDeletableFile(atPath path: String) -> Bool

    // MARK: touch tree structure

    func createDirectory(at url: URL,
                         withIntermediateDirectories createIntermediates: Bool,
                         attributes: [FileAttributeKey: Any]?) throws

    func removeItem(at URL: URL) throws
}

/// Extending FileManager with abstract protocol
extension FileManager: FileManagerable {}
