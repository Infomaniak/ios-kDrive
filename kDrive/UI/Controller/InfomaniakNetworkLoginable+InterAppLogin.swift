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
import InfomaniakDeviceCheck
import InfomaniakLogin
import InterAppLogin
import kDriveCore

extension InfomaniakNetworkLoginable {
    private var deviceCheckEnvironment: InfomaniakDeviceCheck.Environment {
        switch ApiEnvironment.current {
        case .prod:
            return .prod
        case .preprod:
            return .preprod
        case .customHost(let host):
            return .init(url: URL(string: "https://\(host)/1/attest")!)
        }
    }

    func derivateApiToken(for account: ConnectedAccount) async throws -> ApiToken {
        try await derivateApiToken(account.token)
    }

    func derivateApiToken(_ token: ApiToken) async throws -> ApiToken {
        let attestationToken = try await InfomaniakDeviceCheck(environment: deviceCheckEnvironment)
            .generateAttestationFor(
                targetUrl: FactoryService.loginConfig.loginURL.appendingPathComponent("token"),
                bundleId: FactoryService.bundleId,
                bypassValidation: deviceCheckEnvironment == .preprod
            )

        let derivatedToken = try await derivateApiToken(
            using: token,
            attestationToken: attestationToken
        )

        return derivatedToken
    }
}
