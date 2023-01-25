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

/// Something that can build a type
public struct Factory {
    
    public typealias FactoryClosure = ((_ parameters: [String: Any]?, _ resolver: SimpleResolvable)->Any)

    var closure: FactoryClosure
    var type :Any.Type
    
    public init<Service>(type: Service.Type, closure: @escaping FactoryClosure) {
        self.closure = closure
        self.type = type
    }
    
    public func build(factoryParameters: [String: Any]? = nil,
                      resolver: SimpleResolvable = SimpleResolver.sharedResolver) -> Any {
        closure(factoryParameters, resolver)
    }
    
}
