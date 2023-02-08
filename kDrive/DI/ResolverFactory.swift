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
import os.log

/// Something that can associate a custom identifier with a `Factory`
public typealias FactoryWithIdentifier = (factory: Factory, identifier: String?)

/// Something that setups the service factories
///
/// Trick : enum as no init, perfect for namespacing
enum FactoryService {
    static func setupDependencyInjection() {
#if DEBUG
        SimpleResolver.register(debugServicies)
#endif
        let factories = networkingServicies + uploadServicies + miscServicies
        SimpleResolver.register(factories)
    }

    /// Networking related servicies
    private static var networkingServicies: [Factory] {
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
        return servicies
    }

    /// Misc servicies
    private static var uploadServicies: [Factory] {
        let servicies = [
            Factory(type: UploadQueue.self) { _, _ in
                UploadQueue()
            },
            Factory(type: UploadQueueable.self) { _, resolver in
                try resolver.resolve(type: UploadQueue.self,
                                     forCustomTypeIdentifier: nil,
                                     factoryParameters: nil,
                                     resolver: resolver)
            },
            Factory(type: UploadNotifiable.self) { _, resolver in
                try resolver.resolve(type: UploadQueue.self,
                                     forCustomTypeIdentifier: nil,
                                     factoryParameters: nil,
                                     resolver: resolver)
            },
            Factory(type: UploadProgressable.self) { _, resolver in
                try resolver.resolve(type: UploadQueue.self,
                                     forCustomTypeIdentifier: nil,
                                     factoryParameters: nil,
                                     resolver: resolver)
            },
        ]
        return servicies
    }
    
    /// Misc servicies
    private static var miscServicies: [Factory] {
        let servicies = [
            Factory(type: AppLockHelper.self) { _, _ in
                AppLockHelper()
            },
            Factory(type: FileManagerable.self) { _, _ in
                FileManager.default
            },
        ]
        return servicies
    }
    
#if DEBUG
    /// Debug servicies
    private static var debugServicies: [FactoryWithIdentifier] {
        if #available(iOS 14.0, *) {
            let loggerFactory = Factory(type: Logger.self) { parameters, _ in
                guard let category = parameters?["category"] as? String else {
                    fatalError("Please pass a category")
                }
                let subsystem = Bundle.main.bundleIdentifier!
                return Logger(subsystem: subsystem, category: category)
            }
            
            let servicies = [
                (loggerFactory, "UploadOperation"),
                (loggerFactory, "CloseUploadSessionOperation"),
                (loggerFactory, "BackgroundSessionManager"),
                (loggerFactory, "UploadQueue"),
            ]
            return servicies
        } else {
            return []
        }
    }
#endif
}

extension SimpleResolver {
    static func register(_ factories: [Factory]) {
        factories.forEach { SimpleResolver.sharedResolver.store(factory: $0) }
    }
    
    static func register(_ factoriesWithIdentifier: [FactoryWithIdentifier]) {
        factoriesWithIdentifier.forEach { SimpleResolver.sharedResolver.store(factory: $0.0, forCustomTypeIdentifier: $0.1) }
    }
}
