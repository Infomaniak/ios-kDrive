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

/// A strcuture to select the stack to use
///
/// this is a draft, there is probably a more aestetic way to do it
extension ApiFetcher: RequestDispatchable {
    static let contentType = "Content-Type"

    public func dispatch<Result: Decodable>(_ requestable: Requestable,
                                            networkStack: NetworkStack = .Alamofire) async throws -> Result {
        switch networkStack {
        case .Alamofire:
            return try await dispatchAlamofire(requestable)
        case .NSURLSession:
            return try await dispatchNSURLSession(requestable, inBackground: false)
        case .NSURLSessionBackground:
            return try await dispatchNSURLSession(requestable, inBackground: true)
        }
    }

    // TODO: Update existing method in core with encoding
    func __authenticatedRequest(_ endpoint: Endpoint,
                                method: HTTPMethod = .get,
                                parameters: Parameters? = nil,
                                encoding: ParameterEncoding = JSONEncoding.default,
                                headers: HTTPHeaders? = nil) -> DataRequest {
        return authenticatedSession
            .request(endpoint.url, method: method, parameters: parameters, encoding: encoding, headers: headers)
    }

    /// A bit of overhead is required to make Alamofire perform a request from simple abstracted types.
    func dispatchAlamofire<Result: Decodable>(_ requestable: Requestable) async throws -> Result {
        // Set up URL and associated GET parametes
        let endpoint: Endpoint
        if let queryItems = requestable.GETParameters?.urlComponents.queryItems {
            endpoint = requestable.route.appending(path: "", queryItems: queryItems)
        } else {
            endpoint = requestable.route
        }

        // Set up body and associated POST parameters or multipart Data
        let request: DataRequest
        let body = requestable.body
        let method = requestable.method.alamofireMethod
        switch body {
        case .POSTParameters(let parameters):
            request = authenticatedRequest(endpoint,
                                           method: method,
                                           parameters: parameters)
        case .requestBody(let data):
            let headers: HTTPHeaders = [Self.contentType: "application/octet-stream"]
            request = __authenticatedRequest(endpoint,
                                             method: method,
                                             parameters: nil,
                                             encoding: BodyDataEncoding(data: data),
                                             headers: headers)
        case .none:
            request = authenticatedRequest(endpoint,
                                           method: method,
                                           parameters: nil)
        }

        return try await perform(request: request).data
    }

    func dispatchNSURLSession<Result: Decodable>(_ requestable: Requestable, inBackground: Bool) async throws -> Result {
        var endpoint = requestable.route.url
        if let parameters = requestable.GETParameters,
           let queryItems = parameters.urlComponents.queryItems {
            if #available(iOS 16.0, *) {
                endpoint.append(queryItems: queryItems)
            } else {
                if var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) {
                    components.queryItems = queryItems
                    if let url = components.url {
                        endpoint = url
                    }
                }
            }
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = requestable.method.rawValue

        // append body
        switch requestable.body {
        case .requestBody(let data):
            urlRequest.setValue("application/octet-stream", forHTTPHeaderField: Self.contentType)
            urlRequest.httpBody = data
        case .POSTParameters(let parameters):
            urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: Self.contentType)
            urlRequest.httpBody = parameters.urlEncodedData
        case .none:
            break
        }

        let session: URLSession
        if inBackground {
            session = URLSession(configuration: .default)
        } else {
            // TODO: bgsession handling
            session = URLSession(configuration: .background(withIdentifier: "1337"))
        }

        let tuple = try await session.data(for: urlRequest)
        print("data: \(tuple.0)\n response: \(tuple.1) \n")

        let object = try JSONDecoder().decode(Result.self, from: tuple.0)
        return object
    }
}
