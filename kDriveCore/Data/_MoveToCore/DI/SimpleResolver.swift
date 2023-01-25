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

/// Something minimalist that can resolve a concrete type
public protocol SimpleResolvable {
    /// The main solver funtion, tries to fetch an existing object or apply a factory if availlable
    /// - Parameters:
    ///   - type: the wanted type
    ///   - customIdentifier: use a custom identifier to be able to resolve _many_ objects of the _same_ type
    ///   - factoryParameters: some arguments that can be passed to the factory, customising the requested objects.
    ///   - resolver: something that can resolve a type, usefull for chaining types
    /// - Returns: the
    /// - Throws: will throw if the requested type is unavaillable, or if called not from main thread
    func resolve<Service>(type: Service.Type,
                          forCustomTypeIdentifier customIdentifier: String?,
                          factoryParameters: [String: Any]?,
                          resolver: SimpleResolvable) throws -> Service
}

/// Something that stores a factory for a given type
public protocol SimpleStorable {
    /// Store a factory closure for a given type
    ///
    /// You will virtualy never call this directly
    /// - Parameters:
    ///   - factory: the factory wrapper
    ///   - customIdentifier: use a custom identifier to be able to resolve _many_ objects of the _same_ type
    func store(factory: Factory,
               forCustomTypeIdentifier customIdentifier: String?) throws
}

/// A minimalist DI solution
/// For now, once initiated, stores types as long as the app lives
///
/// Access from Main Queue only
public final class SimpleResolver: SimpleResolvable, SimpleStorable {
    enum ErrorDomain: Error {
        case factoryMissing
        case typeMissmatch
        case notMainThread
    }
    
    // The last singleton that will exist on our code in the end
    public static let sharedResolver = SimpleResolver()
    
    public func store(factory: Factory,
                      forCustomTypeIdentifier customIdentifier: String? = nil) throws {
        guard Thread.isMainThread == true else {
            throw ErrorDomain.notMainThread
        }
        
        let type = factory.type
        
        let identifier = buildIdentifier(type: type, forIdentifier: customIdentifier)
        factories[identifier] = factory
    }
    
    var factories = [String: Factory]()
    var store = [String: Any]()
    
    // MARK: - SimpleResolvable
    
    public func resolve<Service>(type: Service.Type,
                                 forCustomTypeIdentifier customIdentifier: String?,
                                 factoryParameters: [String: Any]? = nil,
                                 resolver: SimpleResolvable) throws -> Service {
        guard Thread.isMainThread == true else {
            throw ErrorDomain.notMainThread
        }
        
        let serviceIdentifier = buildIdentifier(type: type, forIdentifier: customIdentifier)
        
        // try to load form store
        if let service = store[serviceIdentifier] as? Service {
            return service
        }
        
        // try to load service from factory
        guard let factory = factories[serviceIdentifier] else {
            throw ErrorDomain.factoryMissing
        }
        
        // Apply factory closure
        guard let service = factory.build(factoryParameters: factoryParameters, resolver: resolver) as? Service else {
            throw ErrorDomain.typeMissmatch
        }
        
        // set in store
        store[serviceIdentifier] = service
        
        
        return service
    }
    
    // MARK: - internal
    
    func buildIdentifier(type: Any.Type,
                                  forIdentifier identifier: String? = nil) -> String {
        let serviceIdentifier: String
        if let identifier {
            serviceIdentifier = "\(type):\(identifier)"
        } else {
            serviceIdentifier = "\(type)"
        }
        
        return serviceIdentifier
    }
    
    // MARK: - testing
    
    func removeAll() {
        self.factories.removeAll()
        self.store.removeAll()
    }
}

/// A property wrapper that resolves (shared) objects
@propertyWrapper public struct InjectService<Service> {
    private var service: Service!
    
    public var container: SimpleResolvable
    public var customTypeIdentifier: String?
    public var factoryParameters: [String: Any]?
    
    public init(customTypeIdentifier: String? = nil,
                factoryParameters: [String: Any]? = nil,
                container: SimpleResolvable = SimpleResolver.sharedResolver) {
        self.customTypeIdentifier = customTypeIdentifier
        self.factoryParameters = factoryParameters
        self.container = container
    }
    
    public var wrappedValue: Service {
        mutating get {
            do {
                self.service = try container.resolve(type: Service.self,
                                                     forCustomTypeIdentifier: customTypeIdentifier,
                                                     factoryParameters: factoryParameters,
                                                     resolver: container)
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
