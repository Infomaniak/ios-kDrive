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

import Foundation
import InfomaniakDI

public protocol SharedWithMeServiceable: AnyObject {
    func setLastSharedWithMe(_ link: SharedWithMeLink)
    func clearLastSharedWithMe()
    func processSharedWithMePostAuthentication()
}

public class SharedWithMeService: SharedWithMeServiceable {
    @LazyInjectService var router: AppNavigable

    private var sharedWithMeLink: SharedWithMeLink?

    public func setLastSharedWithMe(_ link: SharedWithMeLink) {
        sharedWithMeLink = link
    }

    public func clearLastSharedWithMe() {
        sharedWithMeLink = nil
    }

    public func processSharedWithMePostAuthentication() {
        guard let sharedWithMeLink else {
            return
        }

        Task { @MainActor in
            await router.navigate(to: .sharedWithMe(sharedWithMeLink: sharedWithMeLink))
            clearLastSharedWithMe()
        }
    }
}
