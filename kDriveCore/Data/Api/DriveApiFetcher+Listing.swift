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
               sortType: SortType = .nameAZ) async throws -> (data: ListingResult, response: ApiResponse<ListingResult>) {
        try await perform(request: authenticatedRequest(
            .fileListing(file: directory)
                .sorted(by: [.type, sortType]),
            method: .get
        ))
    }

    func files(in directory: ProxyFile,
               listingCursor: FileCursor,
               sortType: SortType = .nameAZ) async throws -> (data: ListingResult, response: ApiResponse<ListingResult>) {
        try await perform(request: authenticatedRequest(
            .fileListingContinue(file: directory, cursor: listingCursor)
                .sorted(by: [.type, sortType]),
            method: .get
        ))
    }

    func files(in directory: ProxyFile,
               listingCursor: FileCursor?,
               sortType: SortType = .nameAZ) async throws -> (data: ListingResult, response: ApiResponse<ListingResult>) {
        if let listingCursor {
            return try await files(in: directory, listingCursor: listingCursor, sortType: sortType)
        } else {
            return try await files(in: directory, sortType: sortType)
        }
    }
}
