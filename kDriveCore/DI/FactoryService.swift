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
import os.log

/// Something that can associate a custom identifier with a `Factory`
public typealias FactoryWithIdentifier = (factory: Factory, identifier: String?)

private let appGroupName = "group.com.infomaniak.drive"
private let realmRootPath = "drives"
private let loginConfig = InfomaniakLogin.Config(clientId: "9473D73C-C20F-4971-9E10-D957C563FA68", accessType: nil)

/// Something that setups the service factories
public enum FactoryService {
    public static func setupDependencyInjection(other: [Factory] = []) {
        SimpleResolver.register(debugServices)
        let factories = networkingServices + miscServices + other
        SimpleResolver.register(factories)
    }

    /// Networking related services
    private static var networkingServices: [Factory] {
        let services = [
            Factory(type: InfomaniakNetworkLogin.self) { _, _ in
                return InfomaniakNetworkLogin(config: loginConfig)
            },
            Factory(type: InfomaniakNetworkLoginable.self) { _, resolver in
                try resolver.resolve(type: InfomaniakNetworkLogin.self,
                                     forCustomTypeIdentifier: nil,
                                     factoryParameters: nil,
                                     resolver: resolver)
            },
            Factory(type: InfomaniakLoginable.self) { _, _ in
                InfomaniakLogin(config: loginConfig)
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
            }
        ]
        return services
    }

    /// Misc services
    private static var miscServices: [Factory] {
        let services = [
            Factory(type: UploadQueue.self) { _, _ in
                UploadQueue()
            },
            Factory(type: UploadQueueable.self) { _, resolver in
                try resolver.resolve(type: UploadQueue.self,
                                     forCustomTypeIdentifier: nil,
                                     factoryParameters: nil,
                                     resolver: resolver)
            },
            Factory(type: UploadQueueObservable.self) { _, resolver in
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
            Factory(type: BGTaskScheduler.self) { _, _ in
                BGTaskScheduler.shared
            },
            Factory(type: AppLockHelper.self) { _, _ in
                AppLockHelper()
            },
            Factory(type: FileManagerable.self) { _, _ in
                FileManager.default
            },
            Factory(type: FileMetadatable.self) { _, _ in
                FileMetadata()
            },
            Factory(type: FreeSpaceService.self) { _, _ in
                FreeSpaceService()
            },
            Factory(type: NotificationsHelpable.self) { _, _ in
                NotificationsHelper()
            },
            Factory(type: FileProviderExtensionAdditionalStatable.self) { _, _ in
                FileProviderExtensionAdditionalState()
            },
            Factory(type: AppGroupPathProvidable.self) { _, _ in
                guard let provider = AppGroupPathProvider(realmRootPath: realmRootPath, appGroupIdentifier: appGroupName) else {
                    fatalError("unable to initialise AppGroupPathProvider securely")
                }
                return provider
            },
            Factory(type: PhotoLibrarySavable.self) { _, _ in
                PhotoLibrarySaver()
            },
            Factory(type: BackgroundTasksServiceable.self) { _, _ in
                BackgroundTasksService()
            },
            Factory(type: ReviewManageable.self) { _, _ in
                ReviewManager(userDefaults: UserDefaults.shared, openingBeforeReview: 3)
            }
        ]
        return services
    }

    /// Debug services
    static var debugServices: [FactoryWithIdentifier] {
        if #available(iOS 14.0, *) {
            let loggerFactory = Factory(type: Logger.self) { parameters, _ in
                guard let category = parameters?["category"] as? String else {
                    fatalError("Please pass a category")
                }
                let subsystem = Bundle.main.bundleIdentifier!
                return Logger(subsystem: subsystem, category: category)
            }

            let services = [
                (loggerFactory, "UploadOperation"),
                (loggerFactory, "BackgroundSessionManager"),
                (loggerFactory, "UploadQueue"),
                (loggerFactory, "BGTaskScheduling"),
                (loggerFactory, "PhotoLibraryUploader"),
                (loggerFactory, "AppDelegate"),
                (loggerFactory, "FileProvider"),
                (loggerFactory, "DriveInfosManager")
            ]
            return services
        } else {
            return []
        }
    }
}

public extension SimpleResolver {
    static func register(_ factories: [Factory]) {
        factories.forEach { SimpleResolver.sharedResolver.store(factory: $0) }
    }

    static func register(_ factoriesWithIdentifier: [FactoryWithIdentifier]) {
        factoriesWithIdentifier.forEach { SimpleResolver.sharedResolver.store(factory: $0.0, forCustomTypeIdentifier: $0.1) }
    }
}
