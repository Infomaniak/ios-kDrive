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

import DeviceAssociation
import Foundation
import InfomaniakCore
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import OSLog

public struct TokenMigrator {
    @InjectService private var tokenStore: TokenStore
    @InjectService private var deviceManager: DeviceManagerable
    @InjectService private var networkLoginService: InfomaniakNetworkLoginable
    @InjectService private var accountManager: AccountManageable

    private let logger = Logger(category: "TokenMigrator")

    public init() {}

    public func migrateTokensIfNeeded() async {
        let migratedTokens = await withTaskGroup { group in
            for token in tokenStore.getAllTokens().values {
                group.addTask {
                    await migrateTokenIfNeeded(token: token)
                }
            }

            var migratedOneToken = false
            for await migrated in group {
                migratedOneToken = migratedOneToken || migrated
            }

            return migratedOneToken
        }

        if migratedTokens {
            accountManager.removeCachedProperties()
        }
    }

    private func migrateTokenIfNeeded(token: AssociatedApiToken) async -> Bool {
        do {
            let device = try await deviceManager.getOrCreateCurrentDevice()
            guard token.deviceId != nil else {
                logToSentry(
                    message: "No device id associated to token - Updating token with current device id",
                    token: token,
                    device: device
                )

                tokenStore.addToken(newToken: token.apiToken, associatedDeviceId: device.uid)
                return false
            }

            guard let currentDeviceId = token.deviceId,
                  currentDeviceId != device.uid else {
                logToSentry(message: "No need to migrate token", token: token, device: device)
                return false
            }

            logToSentry(message: "Token associated device id different from current device id", token: token, device: device)

            guard let derivatedToken = try? await networkLoginService.derivateApiToken(token.apiToken) else {
                logToSentry(message: "New token derivation failed - Removing account", token: token, device: device)
                accountManager.removeTokenAndAccount(account: Account(apiToken: token.apiToken))
                return false
            }

            tokenStore.removeTokenFor(userId: token.userId)
            tokenStore.addToken(newToken: derivatedToken, associatedDeviceId: device.uid)
            logToSentry(message: "New token derived and stored with current device id", token: token, device: device)

            return true
        } catch {
            logger.error("Failed migrating token: \(error)")

            SentryDebug.capture(error: error,
                                context: [
                                    "User id": token.userId,
                                    "Token": token.apiToken.truncatedAccessToken
                                ],
                                contextKey: "TokenMigrator",
                                extras: nil)
            return false
        }
    }

    private func logToSentry(message: String, token: AssociatedApiToken, device: UserDevice) {
        logger.info("\(message)")

        SentryDebug.addBreadcrumb(
            message: message,
            category: .tokenMigrator,
            level: .info,
            metadata: ["User id": token.userId,
                       "Device id": device.uid,
                       "Token Device Id": device.uid,
                       "Token": token.apiToken.truncatedAccessToken]
        )
    }
}
