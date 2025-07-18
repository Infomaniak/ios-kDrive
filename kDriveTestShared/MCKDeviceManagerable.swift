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

import Alamofire
import DeviceAssociation
import Foundation
@testable import InfomaniakCore
import InfomaniakLogin
import kDriveCore

public struct MCKDeviceManagerable: DeviceManagerable {
    public func getOrCreateCurrentDevice() async throws -> UserDevice {
        await UserDevice(uid: UUID.emptyUUIDString)
    }

    @discardableResult
    public func attachDevice(_ device: UserDevice, to token: ApiToken,
                             apiFetcher: ApiFetcher) async throws -> ValidServerResponse<Bool> {
        let headers = HTTPHeaders()
        let content = ValidApiResponse<Bool>(result: ApiResult.success,
                                             data: true,
                                             total: nil,
                                             pages: nil,
                                             page: nil,
                                             itemsPerPage: nil,
                                             responseAt: nil,
                                             cursor: nil,
                                             hasMore: false)
        let response = ValidServerResponse<Bool>(statusCode: 200,
                                                 responseHeaders: headers,
                                                 validApiResponse: content)
        return response
    }
}

public extension UUID {
    static var emptyUUIDString: String {
        "00000000-0000-0000-0000-000000000000"
    }
}
