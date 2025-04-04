/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

/// Something that centralize the App Restoration logic
public protocol AppRestorationServiceable {
    /// Is restoration enabled
    var shouldRestoreApplicationState: Bool { get }

    /// Should save the scene sate
    var shouldSaveApplicationState: Bool { get }

    /// Saves a restoration version, for forward compatibility
    func saveRestorationVersion()

    func reloadAppUI(for driveId: Int, userId: Int) async
}
