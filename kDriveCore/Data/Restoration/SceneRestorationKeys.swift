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

/// ViewController identifiers for state restoration
public enum SceneRestorationScreens: String {
    /// Preview a file
    case PreviewViewController

    /// Metadata of the file
    case FileDetailViewController

    /// File listing view
    case FileListViewController

    /// InApp purchase
    case StoreViewController
}

public enum SceneRestorationKeys: String {
    /// The selected index of the MainViewController that should be restored
    case selectedIndex

    /// Array representing the stack of view controllers that should be restored
    // TODO: Implement stack restoration
    // case fileViewStack

    /// The screen that should be restored on top of the MainViewController
    case lastViewController
}

/// Keys used for Scene based restoration
public enum SceneRestorationValues: String {
    case driveId
    case fileId

    // Preview View controller keys
    public enum Carousel: String {
        case filesIds
        case currentIndex
        case normalFolderHierarchy
        case fromActivities
    }
}
