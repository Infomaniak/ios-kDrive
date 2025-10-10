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
import InAppTwoFactorAuthentication
import InfomaniakConcurrency
import InfomaniakDI

public struct InAppTwoFactorAuthenticationHelper: Sendable {
    public init() {}

    public func checkTwoFAChallenges() async {
        @InjectService var accountManager: AccountManageable

        let accounts = accountManager.accounts.values

        let sessions: [InAppTwoFactorAuthenticationSession] = await accounts.asyncCompactMap { account in
            guard let user = account.user,
                  let token = account.token else {
                return nil
            }

            let apiFetcher = accountManager.getApiFetcher(for: account.userId, token: token)

            let session = InAppTwoFactorAuthenticationSession(user: user, apiFetcher: apiFetcher)
            return session
        }

        @InjectService var inAppTwoFactorAuthenticationManager: InAppTwoFactorAuthenticationManagerable
        inAppTwoFactorAuthenticationManager.checkConnectionAttempts(using: sessions)
    }
}
