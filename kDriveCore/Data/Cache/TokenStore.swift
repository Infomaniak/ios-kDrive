/*
 Infomaniak Mail - iOS App
 Copyright (C) 2022 Infomaniak Network SA

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
import InfomaniakDI
import InfomaniakLogin

public class TokenStore {
    public enum TokenStoreFetchLocation {
        case cache
        case keychain
    }

    public typealias UserId = Int
    @LazyInjectService private var keychainHelper: InfomaniakCore.KeychainHelper
    private let tokens = SendableDictionary<UserId, ApiToken>()

    public init() {
        let keychainTokens = keychainHelper.loadTokens()
        for token in keychainTokens {
            tokens[token.userId] = token
        }
    }

    @discardableResult
    public func removeTokenFor(userId: UserId) -> ApiToken? {
        let removedToken = tokens.removeValue(forKey: userId)
        keychainHelper.deleteToken(for: userId)

        return removedToken
    }

    @discardableResult
    public func removeTokenFor(account: Account) -> ApiToken? {
        return removeTokenFor(userId: account.userId)
    }

    public func tokenFor(userId: UserId, fetchLocation: TokenStoreFetchLocation = .cache) -> ApiToken? {
        if fetchLocation == .keychain {
            let keychainTokens = keychainHelper.loadTokens()
            for token in keychainTokens {
                tokens[token.userId] = token
            }
        }

        return tokens[userId]
    }

    public func addToken(newToken: ApiToken) {
        keychainHelper.storeToken(newToken)
        tokens[newToken.userId] = newToken
    }
}
