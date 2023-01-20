//
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
import Alamofire
import InfomaniakCore

/// Wrapping HTTP POST and GET parameters in this type
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

/// Custom type to abstract AFi
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

/// Bridge to AFi
extension Method {
    var alamofireMethod: Alamofire.HTTPMethod {
        Alamofire.HTTPMethod(rawValue: self.rawValue)
    }
}

/// Wrapping data into an AFi encoder
struct BodyDataEncoding: ParameterEncoding {

    private let data: Data

    init(data: Data) {
        self.data = data
    }

    func encode(_ urlRequest: URLRequestConvertible,
                with parameters: Parameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        request.httpBody = data
        return request
    }
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
