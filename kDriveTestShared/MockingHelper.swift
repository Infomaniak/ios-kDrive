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
@testable import InfomaniakDI
@testable import kDrive
@testable import kDriveCore

public enum MockingConfig {
    /// Full app, able to perform network calls.
    /// The app is unaware of the tests
    /// Perfect for UItests
    case realApp

    /// Full app, network stack is NOOP
    case mockedNetwork
}

/// Something to help using the DI in the test target
public enum MockingHelper {
    /// Register "real" instances like in the app
    static func registerConcreteTypes() {
        let extraFactories = [
            Factory(type: AppContextServiceable.self) { _, _ in
                AppContextService(context: .appTests)
            }
        ]

        /* TODO:
         var extraDependencies = [
             Factory(type: NavigationManageable.self) { _, _ in
                 NavigationManager()
             },
             Factory(type: AppContextServiceable.self) { _, _ in
                 AppContextService(context: context)
             }
         ]

         #if !ISEXTENSION
         extraDependencies += [
             Factory(type: AppRestorationServiceable.self) { _, _ in
                 AppRestorationService()
             },
             Factory(type: AppNavigable.self) { _, _ in
                 AppRouter()
             }
         ]
         #endif
         */

        FactoryService.setupDependencyInjection(other: extraFactories)
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
