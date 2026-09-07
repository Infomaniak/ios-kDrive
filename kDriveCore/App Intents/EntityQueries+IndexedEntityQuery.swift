/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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

import AppIntents
import CoreSpotlight
import Foundation
import InfomaniakDI

@available(iOS 27.0, *)
extension KDriveFileEntity.KDriveEntityQuery: IndexedEntityQuery {
    func reindexEntities(for identifiers: [FileEntityIdentifier], indexDescription: CSSearchableIndexDescription) async throws {
        let entities = try await entities(for: identifiers)

        try await CSSearchableIndex(name: SpotlightIndexer.spotlightIndexName).indexAppEntities(entities)
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        SpotlightIndexer.shared.indexAllItems()
    }
}
