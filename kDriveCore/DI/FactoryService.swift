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

import BackgroundTasks
import Foundation
import InfomaniakCore
import InfomaniakCoreUI
import InfomaniakDI
import InfomaniakLogin

/// Something that setups the service factories
///
/// Trick : enum as no init, perfect for namespacing
public enum FactoryService {
    public static func setupDependencyInjection() {
        let factories = networkingServices + miscServices
        SimpleResolver.register(factories)
    }

    /// Networking related services
    private static var networkingServices: [Factory] {
        let services = [
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
            Factory(type: UploadTokenManager.self) { _, _ in
                UploadTokenManager()
            },
            Factory(type: BackgroundUploadSessionManager.self) { _, _ in
                BackgroundUploadSessionManager()
            },
            Factory(type: BackgroundDownloadSessionManager.self) { _, _ in
                BackgroundDownloadSessionManager()
            },
            Factory(type: PhotoLibraryUploader.self) { _, _ in
                PhotoLibraryUploader()
            },
            Factory(type: FileImportHelper.self) { _, _ in
                FileImportHelper()
            },
        ]
        return services
    }

    /// Misc services
    private static var miscServices: [Factory] {
        let services = [
            Factory(type: UploadQueue.self) { _, _ in
                UploadQueue()
            },
            Factory(type: AppLockHelper.self) { _, _ in
                AppLockHelper()
            },
            Factory(type: BGTaskScheduler.self) { _, _ in
                BGTaskScheduler.shared
            },
        ]
        return services
    }
}

public extension SimpleResolver {
    static func register(_ factories: [Factory]) {
        factories.forEach { SimpleResolver.sharedResolver.store(factory: $0) }
    }
}

/// Something that loads the DI on init
public struct EarlyDIHook {
    public init() {
        // setup DI ASAP
        FactoryService.setupDependencyInjection()
    }
}
