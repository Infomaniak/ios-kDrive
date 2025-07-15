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
import UIKit

// TODO: Move to ios-core

public enum DeviceType: String {
    case computer
    case phone
    case tablet

    static var current: DeviceType {
        let deviceType = UIDevice.current.userInterfaceIdiom
        switch deviceType {
        case .phone:
            return .phone
        case .pad:
            return .tablet
        case .mac:
            return .computer
        default:
            return .computer
        }
    }
}

public enum DeviceOS: String {
    case ios
    case macos

    static var current: DeviceOS {
        let deviceType = UIDevice.current.userInterfaceIdiom
        switch deviceType {
        case .phone, .pad:
            return .ios
        default:
            return .macos
        }
    }
}

public struct DeviceMetaData {
    let make: String = "Apple"
    let model: String?
    let platform: DeviceOS
    let type: DeviceType
    let uid: String

    public init() {
        model = Self.deviceIdentifier
        platform = DeviceOS.current
        type = DeviceType.current
        uid = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    var asParameters: [String: String] {
        var parameters = ["platform": platform.rawValue,
                          "type": type.rawValue,
                          "uid": uid]

        if let make, make.isEmpty == false {
            parameters["make"] = make
        }

        if let model, model.isEmpty == false {
            parameters["model"] = model
        }

        return parameters
    }

    // todo factorise with UserAgentBuilder.modelIdentifier
    static var deviceIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

public extension DriveApiFetcher {
    func attachDevice(toAPIToken token: ApiToken,
                      deviceMetaData: DeviceMetaData) async throws -> ValidServerResponse<Bool> {
        return try await perform(request: authenticatedRequest(
            .attachDevice(toApiToken: token),
            method: .post,
            parameters: deviceMetaData.asParameters
        ))
    }
}
