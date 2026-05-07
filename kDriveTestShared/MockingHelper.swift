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

@testable import DeviceAssociation
import Foundation
@testable import InfomaniakCore
@testable import InfomaniakDI
@testable import kDrive
@testable import kDriveCore

public enum MockingConfiguration {
    /// Full app, able to perform network calls.
    /// The app is unaware of the tests
    /// Perfect for UItests
    case realApp

    // TODO: make sure only the minimal set of real object is set in DI
    /// Minimal real objects
    /// Mocked navigation and networking stack…
    case minimal
}

public class MockingHelper: FactoryService {
    private static var configuration: MockingConfiguration?

    private static let realAppFactories = [
        Factory(type: AppContextServiceable.self) { _, _ in
            AppContextService(context: .app)
        },
        Factory(type: AppRestorationServiceable.self) { _, _ in
            AppRestorationService()
        },
        Factory(type: AppNavigable.self) { _, _ in
            AppRouter()
        },
        Factory(type: PhotoLibraryUploader.self) { _, _ in
            PhotoLibraryUploader()
        },
        Factory(type: PhotoLibraryUploadable.self) { _, resolver in
            try resolver.resolve(type: PhotoLibraryUploader.self,
                                 forCustomTypeIdentifier: nil,
                                 factoryParameters: nil,
                                 resolver: resolver)
        },
        Factory(type: PhotoLibraryQueryable.self) { _, resolver in
            try resolver.resolve(type: PhotoLibraryUploader.self,
                                 forCustomTypeIdentifier: nil,
                                 factoryParameters: nil,
                                 resolver: resolver)
        },
        Factory(type: PhotoLibraryScanable.self) { _, resolver in
            try resolver.resolve(type: PhotoLibraryUploader.self,
                                 forCustomTypeIdentifier: nil,
                                 factoryParameters: nil,
                                 resolver: resolver)
        },
        Factory(type: PhotoLibrarySyncable.self) { _, resolver in
            try resolver.resolve(type: PhotoLibraryUploader.self,
                                 forCustomTypeIdentifier: nil,
                                 factoryParameters: nil,
                                 resolver: resolver)
        }
    ]

    private static let minimalFactories = [
        Factory(type: AppContextServiceable.self) { _, _ in
            AppContextService(context: .appTests)
        },
        Factory(type: AppRestorationServiceable.self) { _, _ in
            AppRestorationService()
        },
        Factory(type: AppNavigable.self) { _, _ in
            MCKRouter()
        },
        Factory(type: PhotoLibraryUploadable.self) { _, _ in
            MCKPhotoLibraryUploadable()
        },
        Factory(type: PhotoLibraryQueryable.self) { _, _ in
            MCKPhotoLibraryQueryable()
        },
        Factory(type: PhotoLibraryScanable.self) { _, _ in
            MCKPhotoLibraryScanable()
        },
        Factory(type: PhotoLibrarySyncable.self) { _, _ in
            MCKPhotoLibrarySyncable()
        },
        Factory(type: DeviceManagerable.self) { _, _ in
            MCKDeviceManagerable()
        }
    ]

    public init(configuration: MockingConfiguration) {
        Self.configuration = configuration
        super.init()
    }

    override public class func getTargetServices() -> [Factory] {
        guard let configuration else {
            fatalError("Configuration should be initialized.")
        }

        let extraFactories: [Factory]

        switch configuration {
        case .realApp:
            extraFactories = realAppFactories
        case .minimal:
            extraFactories = minimalFactories
        }

        return super.getTargetServices() + extraFactories
    }

    /// Register most instances with mocks
    static func registerMockedTypes() {
        fatalError("TODO")
    }

    /// Clear stored types in DI
    static func clearRegisteredTypes() {
        SimpleResolver.sharedResolver.removeAll()
    }
}
