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

public extension DriveApiFetcher {
    func files(in directory: ProxyFile,
               sortType: SortType = .nameAZ) async throws -> ValidServerResponse<ListingResult> {
        try await perform(request: authenticatedRequest(
            .fileListing(file: directory)
                .sorted(by: [.type, sortType]),
            method: .get
        ))
    }

    func files(in directory: ProxyFile,
               advancedListingCursor: FileCursor,
               sortType: SortType = .nameAZ) async throws -> ValidServerResponse<ListingResult> {
        try await perform(request: authenticatedRequest(
            .fileListingContinue(file: directory, cursor: advancedListingCursor)
                .sorted(by: [.type, sortType]),
            method: .get
        ))
    }

    func files(in directory: ProxyFile,
               advancedListingCursor: FileCursor?,
               sortType: SortType = .nameAZ) async throws -> ValidServerResponse<ListingResult> {
        if let advancedListingCursor {
            return try await files(in: directory, advancedListingCursor: advancedListingCursor, sortType: sortType)
        } else {
            return try await files(in: directory, sortType: sortType)
        }
    }

    func filesLastActivities(
        files: [File],
        drive: AbstractDrive
    ) async throws -> [PartialFileActivity] {
        try await perform(request: authenticatedRequest(
            .filePartialListing(drive: drive),
            method: .post,
            parameters: FileLastActivityBody(files: files)
        ))
    }
}
