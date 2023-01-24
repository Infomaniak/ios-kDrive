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
import NIOPosix

/// Something that can build a type
typealias FactoryClosure = ((_ parameters: [String: Any]?) -> Any)

/// Something that can resolve an instance of an object
public protocol SimpleResolvable {
    
    func resolve<Service>(type: Service.Type, forIdentifier identifier: String?) throws -> Service
    
}

/// A minimalist DI solution
///
/// Access from Main Queue only
final class SimpleResolver: SimpleResolvable {
    
    enum ErrorDomain: Error {
        case factoryMissing
        case typeMissmatch
    }
    
    // The last singleton that will exist
    static let sharedResolver = SimpleResolver()
    
    func store(_ factory: @escaping FactoryClosure, forTypeIdentifier identifier: String) {
        assert(Thread.isMainThread == true, "This minimalist DI is main thread only for now")
        factories[identifier] = factory
    }
    
    private var factories = [String: FactoryClosure]()
    private var store = [String: AnyObject]()
    
    // MARK: - SimpleResolvable
    
    func resolve<Service>(type: Service.Type, forIdentifier identifier: String?) throws -> Service {
        assert(Thread.isMainThread == true, "This minimalist DI is main thread only for now")
        
        let serviceIdentifier: String
        if let identifier {
            serviceIdentifier = "\(type):\(identifier)"
        } else {
            serviceIdentifier = "\(type)"
        }
        
        // try to load form store
        if let service = store[serviceIdentifier] as? Service {
            return service
        }
        
        // try to load service from factory
        guard let factory = factories[serviceIdentifier] else {
            throw ErrorDomain.factoryMissing
        }
        
        guard let service = factory(nil) as? Service else {
            throw ErrorDomain.typeMissmatch
        }
        
        return service
    }
    
}

/// A property wrapper that resolves shared objects
@propertyWrapper struct InjectService<Service> {

    private var service: Service!
    public var container: SimpleResolvable
    public var identifier: String?
    
    public init(identifier: String? = nil, container: SimpleResolvable = SimpleResolver.sharedResolver) {
        self.identifier = identifier
        self.container = container
    }
    
    public var wrappedValue: Service {
        mutating get {
            do {
                self.service = try container.resolve(type: Service.self, forIdentifier: identifier)
            } catch {
                fatalError("DI fatal error :\(error)")
            }
            return service
        }
        mutating set {
            service = newValue
        }
    }
    
    public var projectedValue: InjectService<Service> {
        get {
            return self
        }
        mutating set {
            self = newValue
        }
    }
}
