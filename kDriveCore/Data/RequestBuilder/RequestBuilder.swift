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

typealias Parameters = [String: Any]

enum RequestBody {
    case POSTParameters(Parameters)
    case requestBody(Data)
}

/// An abstract representation of a network call
protocol Requestable {
    
    var route: Endpoint { get set }
    
    var GETParameters: Parameters? { get set }
    
    var body: RequestBody? { get set }
    
    
}

/// A minimalist structure to build abstract network calls
struct RequestBuilder {
    
    func buildRequest() -> Requestable {
        fatalError()
    }
    
}

enum NetworkStack {
    case Alamofire
    case NSURLSession
    case NSURLSessionBackground
}

/// A strcuture to select
struct RequestDispatcher {
 
    func dispatch<Result>(_ requestable: Requestable, networkStack: NetworkStack = .Alamofire) async throws -> Result {
        fatalError()
    }
    
}
