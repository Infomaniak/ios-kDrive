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
import InfomaniakDI
import kDriveCore

/// Something that setups the service factories
///
/// Trick : enum as no init, perfect for namespacing
enum FactoryService {
    static func setupDependencyInjection() {
        for factory in serviceFactories() {
            do {
                try SimpleResolver.sharedResolver.store(factory: factory)
            }
            catch {
                assertionFailure("unexpected DI error \(error)")
            }
        }
    }

    private static func serviceFactories() -> [Factory] {
        let factories = [
            // ChunkService factory
            Factory(type: ChunkService.self) { _, _ in
                ChunkService()
            },
        ]

        return factories
    }
}
