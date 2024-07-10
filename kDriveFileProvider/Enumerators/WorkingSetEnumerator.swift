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
import InfomaniakDI
import kDriveCore

final class WorkingSetEnumerator: NSObject, NSFileProviderEnumerator {
    let driveFileManager: DriveFileManager
    let domain: NSFileProviderDomain?

    init(driveFileManager: DriveFileManager, domain: NSFileProviderDomain?) {
        self.driveFileManager = driveFileManager
        self.domain = domain
    }

    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        let workingSetFiles = driveFileManager.getWorkingSet()
        var containerItems = [NSFileProviderItem]()
        for file in workingSetFiles {
            autoreleasepool {
                containerItems.append(file.toFileProviderItem(
                    parent: .workingSet,
                    drive: driveFileManager.drive,
                    domain: self.domain
                ))
            }
        }
        observer.didEnumerate(containerItems)
        observer.finishEnumerating(upTo: nil)
    }
}
