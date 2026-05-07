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
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import os.log

/// Something that loads the DI on init
public class KDriveTargetAssembly: FactoryService {
    private static var context: DriveAppContext?
    public init(context: DriveAppContext) {
        os_log("EarlyDIHook")
        Self.context = context
        super.init()

        try? SimpleResolver.sharedResolver.resolve(type: MatomoUtils.self,
                                                   forCustomTypeIdentifier: nil,
                                                   resolver: SimpleResolver.sharedResolver)
    }

    override public class func getTargetServices() -> [Factory] {
        guard let context else {
            fatalError("context not initialized")
        }
        var extraDependencies = [
            Factory(type: AppContextServiceable.self) { _, _ in
                AppContextService(context: context)
            },
            Factory(type: AppExtensionRoutable.self) { _, _ in
                AppExtensionRouter()
            }
        ]

        #if ISEXTENSION
        extraDependencies += [
            Factory(type: AppNavigable.self) { _, _ in
                InExtensionRouter()
            }
        ]
        #else
        extraDependencies += [
            Factory(type: AppRestorationServiceable.self) { _, _ in
                AppRestorationService()
            },
            Factory(type: AppNavigable.self) { _, _ in
                AppRouter()
            }
        ]
        #endif

        return super.getTargetServices() + extraDependencies
    }
}
