/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

import InfomaniakCore

public extension DriveFileManager {
    func getFrozenFileFromAPI(driveId: Int, fileId: Int) async -> File? {
        let abstractFile = ProxyFile(driveId: driveId, id: fileId)
        let endpoint = Endpoint.file(abstractFile)

        do {
            let file: File = try await apiFetcher
                .perform(request: apiFetcher.authenticatedRequest(endpoint))
            try database.writeTransaction { mutableRealm in
                mutableRealm.add(file, update: .modified)
            }

            return file.freeze()
        } catch {
            return nil
        }
    }
}
