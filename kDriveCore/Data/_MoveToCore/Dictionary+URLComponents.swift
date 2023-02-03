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

public extension Dictionary where Key == String {
    
    var urlComponents: URLComponents {
        var components = URLComponents()
        components.queryItems = self.map {
            URLQueryItem(name: $0, value: "\($1)")
        }
        return components
    }
    
    /// Renders an URL Encoded string of the content of the present Dictionary
    ///
    /// Uses the URLComponents API
    var urlEncoded: URL? {
        let url = urlComponents.url
        return url
    }
    
    var urlEncodedData: Data? {
        guard let url = self.urlEncoded else {
            return nil
        }
        
        let string = url.absoluteString
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        return data
    }
}
