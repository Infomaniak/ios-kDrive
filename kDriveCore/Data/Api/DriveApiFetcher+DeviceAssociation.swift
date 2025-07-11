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
import InfomaniakCore
import InfomaniakLogin

public struct AttachCallback: Codable {
    let result: String
    let data: Bool
}

public struct DeviceMetaData {
    let make: String?
    let model: String?
    let platform: String
    let type: String
    let uid: String

    public init(make: String?, model: String?, platform: String, type: String, uid: String) {
        self.make = make
        self.model = model
        self.platform = platform
        self.type = type
        self.uid = uid
    }
    
    var asParameters: [String: String] {
        return [
            "make": make ?? "",
            "model": model ?? "",
            "platform": platform,
            "type": type,
            "uid": uid
        ]
    }
}

public extension DriveApiFetcher {
    func attachDevice(toAPIToken token: ApiToken,
                      deviceMetaData: DeviceMetaData) async throws -> ValidServerResponse<AttachCallback> {
        return try await perform(request: authenticatedRequest(
            .attachDevice(toApiToken: token),
            method: .post,
            parameters: deviceMetaData.asParameters
        ))
    }
}
