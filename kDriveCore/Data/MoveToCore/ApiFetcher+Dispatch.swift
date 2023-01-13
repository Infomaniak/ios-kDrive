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
import Alamofire

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
            return try await dispatchNSURLSession(requestable)
        case .NSURLSessionBackground:
            return try await dispatchNSURLSessionBackground(requestable)
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

    func dispatchNSURLSession<Result: Decodable>(_ requestable: Requestable) async throws -> Result {
        let endpoint = requestable.route.url
        let parameters = requestable.GETParameters
        
        let defaultSession = URLSession(configuration: .default)
        
        let urlRequest = MutableURLRequest(url: endpoint)
        urlRequest.httpMethod = requestable.method.rawValue
        
        // append body
        switch requestable.body {
        case .requestBody(let data):
            urlRequest.httpBody = data // TODO missing data header and footer ?
        case .POSTParameters(let parameters):
            urlRequest.httpBody = Data() // TODO encode fields
        case .none:
            break
        }
        
        defaultSession.dataTask(with: urlRequest as URLRequest) { data, response, error in
            print("data: \(data)\n response: \(response) \n error: \(error) \n")
        }
        
        fatalError("implement async")
    }

    func dispatchNSURLSessionBackground<Result: Decodable>(_ requestable: Requestable) async throws -> Result {
        fatalError()
    }
    
}
