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

public typealias Parameters = [String: Any]

/// Wrapping the body of an HTTP Request with common types
public enum RequestBody {
    case POSTParameters(Parameters)
    case requestBody(Data)
}

/// An abstract representation of an HTTP request
public protocol Requestable {
    var method: Method { get set }

    var route: Endpoint { get set }

    var GETParameters: Parameters? { get set }

    var body: RequestBody? { get set }
}

// TODO: Remove
public enum Method: String {
    case GET
    case POST
    case PUT
    case DELETE
    case CONNECT
    case OPTIONS
    case TRACE
    case PATCH
    case TEAPOT
}

public struct Request: Requestable {
    public var method: Method

    public var route: InfomaniakCore.Endpoint

    public var GETParameters: Parameters?

    public var body: RequestBody?
}

public enum NetworkStack {
    case Alamofire
    case NSURLSession
    case NSURLSessionBackground
}

public protocol RequestDispatchable {
    func dispatch<Result: Decodable>(_ requestable: Requestable,
                                     networkStack: NetworkStack) async throws -> Result
}

/// A strcuture to select the stack to use
///
/// this is a draft, there is probably a more aestetic way to do it
extension ApiFetcher: RequestDispatchable {
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

    func dispatchAlamofire<Result: Decodable>(_ requestable: Requestable) async throws -> Result {
        let endpoint = requestable.route
        let parameters = requestable.GETParameters
        let request = authenticatedRequest(endpoint,
                                           method: .post,
                                           parameters: parameters)

        return try await perform(request: request).data
    }

    func dispatchNSURLSession<Result: Decodable>(_ requestable: Requestable, inBackground: Bool) async throws -> Result {
        var endpoint = requestable.route.url
        if let parameters = requestable.GETParameters,
           let queryItems = parameters.urlComponents.queryItems {
            if #available(iOS 16.0, *) {
                endpoint.append(queryItems: queryItems)
            } else {
                var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
                components.queryItems = queryItems
                if let url = components.url {
                    endpoint = url
                }
            }
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = requestable.method.rawValue

        // append body
        switch requestable.body {
        case .requestBody(let data):
            urlRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = data
        case .POSTParameters(let parameters):
            urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = parameters.urlEncodedData
        case .none:
            break
        }

        let session: URLSession
        if inBackground {
            session = URLSession(configuration: .default)
        } else {
            /// TODO bgsession handling
            session = URLSession(configuration: .background(withIdentifier: "1337"))
        }
        
        let tuple = try await session.data(for: urlRequest)
        print("data: \(tuple.0)\n response: \(tuple.1) \n")

        let object = try JSONDecoder().decode(Result.self, from: tuple.0)
        return object
    }

}
