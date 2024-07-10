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

import Alamofire
import Foundation
import InfomaniakCore

extension UploadOperation {
    /// Builds a request to upload a chunk
    /// - Parameters:
    ///   - chunkNumber: Identifier of the chunk
    ///   - chunkSize: The size of the chunk
    ///   - chunkHash: The hash of the chunk
    ///   - sessionToken: The Upload Session token
    ///   - driveId: The target drive
    ///   - accessToken: Oauth token
    ///   - host: The domain to upload to
    /// - Returns: A configured URL request
    func buildRequest(chunkNumber: Int64,
                      chunkSize: Int64,
                      chunkHash: String,
                      sessionToken: String,
                      driveId: Int,
                      accessToken: String,
                      host: String) throws -> URLRequest {
        // Access Token must be added for non AF requests
        let headerParameters = ["Authorization": "Bearer \(accessToken)"]
        let headers = HTTPHeaders(headerParameters)
        let route: Endpoint = .appendChunk(drive: AbstractDriveWrapper(id: driveId),
                                           sessionToken: AbstractTokenWrapper(token: sessionToken))

        guard var urlComponents = URLComponents(url: route.url, resolvingAgainstBaseURL: false) else {
            throw Self.ErrorDomain.unableToBuildRequest
        }

        urlComponents.host = host

        let getParameters = [
            URLQueryItem(name: APIUploadParameter.chunkNumber.rawValue, value: "\(chunkNumber)"),
            URLQueryItem(name: APIUploadParameter.chunkSize.rawValue, value: "\(chunkSize)"),
            URLQueryItem(name: APIUploadParameter.chunkHash.rawValue, value: chunkHash)
        ]
        urlComponents.queryItems = getParameters

        guard let url = urlComponents.url else {
            throw ErrorDomain.unableToBuildRequest
        }

        return try URLRequest(url: url, method: .post, headers: headers)
    }
}
