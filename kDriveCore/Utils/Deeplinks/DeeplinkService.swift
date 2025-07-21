/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

public protocol DeeplinkServiceable: AnyObject {
    func setLastPublicShare(_ link: Any)
    func clearLastPublicShare()
    func processDeeplinksPostAuthentication()
}

public class DeeplinkService: DeeplinkServiceable {
    @LazyInjectService var router: AppNavigable

    private var lastPublicShareLink: Any?

    public func setLastPublicShare(_ link: Any) {
        lastPublicShareLink = link
    }

    public func clearLastPublicShare() {
        lastPublicShareLink = nil
    }

    public func processDeeplinksPostAuthentication() {
        guard let lastPublicShareLink else {
            return
        }

        Task { @MainActor in
            switch lastPublicShareLink {
            case let lastPublicShareLink as PublicShareLink:
                await UniversalLinksHelper.processPublicShareLink(lastPublicShareLink)
            case let lastPublicShareLink as SharedWithMeLink:
                await router.navigate(to: .sharedWithMe(sharedWithMeLink: lastPublicShareLink))
            case let lastPublicShareLink as TrashLink:
                await router.navigate(to: .trash(trashLink: lastPublicShareLink))
            case let lastPublicShareLink as OfficeLink:
                await router.navigate(to: .office(officeLink: lastPublicShareLink))
            default:
                break
            }

            clearLastPublicShare()
        }
    }
}
