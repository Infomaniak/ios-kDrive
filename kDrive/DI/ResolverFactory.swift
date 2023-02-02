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
import InfomaniakCore
import InfomaniakCoreUI
import InfomaniakDI
import InfomaniakLogin
import kDriveCore

/// Something that setups the service factories
///
/// Trick : enum as no init, perfect for namespacing
enum FactoryService {
    static func setupDependencyInjection() {
        let factories = NetworkingServicies + MiscServicies
        SimpleResolver.register(factories)
    }

    /// Networking related servicies
    private static var NetworkingServicies: [Factory] {
        let servicies = [
            Factory(type: InfomaniakNetworkLogin.self) { _, _ in
                let clientId = "9473D73C-C20F-4971-9E10-D957C563FA68"
                let redirectUri = "com.infomaniak.drive://oauth2redirect"
                return InfomaniakNetworkLogin(clientId: clientId, redirectUri: redirectUri)
            },
            Factory(type: InfomaniakNetworkLoginable.self) { _, resolver in
                try resolver.resolve(type: InfomaniakNetworkLogin.self,
                                     forCustomTypeIdentifier: nil,
                                     factoryParameters: nil,
                                     resolver: resolver)
            },
            Factory(type: InfomaniakLoginable.self) { _, _ in
                InfomaniakLogin(clientId: DriveApiFetcher.clientId)
            },
            Factory(type: InfomaniakTokenable.self) { _, resolver in
                try resolver.resolve(type: InfomaniakLoginable.self,
                                     forCustomTypeIdentifier: nil,
                                     factoryParameters: nil,
                                     resolver: resolver)
            },
            Factory(type: AccountManageable.self) { _, _ in
                AccountManager()
            },
        ]
        return servicies
    }

    /// Misc servicies
    private static var MiscServicies: [Factory] {
        let servicies = [
            // ChunkService factory
            Factory(type: ChunkService.self) { _, _ in
                ChunkService()
            },
            Factory(type: UploadQueue.self) { _, _ in
                UploadQueue()
            },
            Factory(type: AppLockHelper.self) { _, _ in
                AppLockHelper()
            }
        ]
        return servicies
    }
}

extension SimpleResolver {
    static func register(_ factories: [Factory]) {
        for factory in factories {
            do {
                try SimpleResolver.sharedResolver.store(factory: factory)
            }
            catch {
                assertionFailure("unexpected DI error \(error)")
            }
        }
    }
}
