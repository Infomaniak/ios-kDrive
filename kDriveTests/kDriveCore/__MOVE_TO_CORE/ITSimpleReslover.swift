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

@testable import kDriveCore
import XCTest

/// Integration Tests of the Simple DI mechanism
final class ITSimpleReslover: XCTestCase {
    
    override func setUp() {
        SimpleResolver.sharedResolver.removeAll()
    }

    override func tearDown() {
        SimpleResolver.sharedResolver.removeAll()
    }
    
    // MARK: - store(factory:)
    
    func testStoreFactory_mainThread() {
        // GIVEN
        let resolver = SimpleResolver.sharedResolver
        let expectedObject = SomeClass()
        var factoryClosureCallCount = 0
        let factory = Factory(type: SomeClass.self) { _, _ in
            factoryClosureCallCount += 1
            return expectedObject
        }
        
        // WHEN
        do {
            try resolver.store(factory: factory)
        }
        
        // THEN
        catch {
            XCTFail("Unexpected \(error)")
        }
        
        XCTAssertEqual(resolver.factories.count, 1)
        XCTAssertEqual(resolver.store.count, 0)
    }
    
    func testStoreFactory_other() {
        // GIVEN
        let resolver = SimpleResolver.sharedResolver
        let expectedObject = SomeClass()
        var factoryClosureCallCount = 0
        let factory = Factory(type: SomeClass.self) { _, _ in
            factoryClosureCallCount += 1
            return expectedObject
        }
        
        let group = DispatchGroup()
        group.enter()

        // WHEN
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try resolver.store(factory: factory)
                XCTFail("This should throw")
            }
            
            // THEN
            catch {
                guard let error = error as? SimpleResolver.ErrorDomain,
                      case SimpleResolver.ErrorDomain.notMainThread = error else {
                    XCTFail("Unexpected \(error)")
                    group.leave()
                    return
                }
                
                // all good
                group.leave()
            }
        }
        
        group.wait()
        
        XCTAssertEqual(resolver.factories.count, resolver.store.count)
        XCTAssertEqual(resolver.factories.count, 0)
        XCTAssertEqual(resolver.store.count, 0)
    }
    
    // MARK: - resolve(type: forCustomTypeIdentifier: resolver:)
    
    func testResolveSampleType_callExplicitResolve() {
        // GIVEN
        let resolver = SimpleResolver.sharedResolver
        let expectedObject = SomeClass()
        var factoryClosureCallCount = 0
        let factory = Factory(type: SomeClass.self) { _, _ in
            factoryClosureCallCount += 1
            return expectedObject
        }
        
        try! resolver.store(factory: factory)
        
        // WHEN
        do {
            let resolved = try resolver.resolve(type: SomeClass.self,
                                                forCustomTypeIdentifier: nil,
                                                resolver: resolver)
            
            // THEN
            XCTAssertTrue(resolved === expectedObject, "identity of resolved object should match")
            XCTAssertEqual(factoryClosureCallCount, 1, "the factory closure should be called once exactly")
        } catch {
            XCTFail("Unexpected: \(error)")
        }
        
        XCTAssertEqual(resolver.factories.count, resolver.store.count)
        XCTAssertEqual(resolver.factories.count, 1)
        XCTAssertEqual(resolver.store.count, 1)
    }
    
    // MARK: - @InjectService
    
    func testResolveSampleType_propertyWrapper() {
        // GIVEN
        let resolver = SimpleResolver.sharedResolver
        let expectedObject = SomeClass()
        var factoryClosureCallCount = 0
        let factory = Factory(type: SomeClass.self) { _, _ in
            factoryClosureCallCount += 1
            return expectedObject
        }
        
        try! resolver.store(factory: factory)
        
        // WHEN
        let classWithDIProperty = AClassThatUsesDI()
        
        // THEN
        XCTAssertTrue(expectedObject === classWithDIProperty.injected, "identity of resolved object should match")
        XCTAssertEqual(factoryClosureCallCount, 1, "the factory closure should be called once exactly")
        
        XCTAssertEqual(resolver.factories.count, resolver.store.count)
        XCTAssertEqual(resolver.factories.count, 1)
        XCTAssertEqual(resolver.store.count, 1)
    }
    
    func testResolveSampleType_propertyWrapper_withCustomIdentifiers() {
        // GIVEN
        let resolver = SimpleResolver.sharedResolver
        var factoryClosureCallCount = 0
        let factory = Factory(type: SomeClass.self) { _, _ in
            factoryClosureCallCount += 1
            return SomeClass()
        }
        
        // We store a factory for a specific specialized type using an identifier
        let specialIdentifier = "specialIdentifier"
        let customIdentifier = "customIdentifier"
        
        try! resolver.store(factory: factory, forCustomTypeIdentifier: specialIdentifier)
        try! resolver.store(factory: factory, forCustomTypeIdentifier: customIdentifier)
        
        // WHEN
        let classWithServicies = AClassThatUsesCustomIdentifiersDI()
        
        // THEN
        XCTAssertFalse(classWithServicies.custom === classWithServicies.special,
                       "`custom` and `special` should be resolved to two distinct objects")
        XCTAssertEqual(factoryClosureCallCount, 2, "the factory closure should be called twice exactly")
        
        XCTAssertEqual(resolver.factories.count, resolver.store.count)
        XCTAssertEqual(resolver.factories.count, 2)
        XCTAssertEqual(resolver.store.count, 2)
    }
    
    func testResolveSampleType_propertyWrapper_withCustomParameters() {
        // GIVEN
        let resolver = SimpleResolver.sharedResolver
        let expectedObject = SomeClass()
        let expectedFactoryParameters = ["someKey": "someValue"]
        var factoryClosureCallCount = 0
        let factory = Factory(type: SomeClass.self) { parameters, _ in
            guard let parameters else {
                XCTFail("unexpected")
                return
            }
            XCTAssertEqual(parameters as NSDictionary, expectedFactoryParameters as NSDictionary)
            factoryClosureCallCount += 1
            return expectedObject
        }

        try! resolver.store(factory: factory)
        
        // WHEN
        let classWithService = AClassThatUsesFactoryParametersDI()
        
        // THEN
        XCTAssertTrue(classWithService.injected === expectedObject, "the identity is expected to match")
        XCTAssertEqual(factoryClosureCallCount, 1, "the factory closure should be called twice exactly")
        
        XCTAssertEqual(resolver.factories.count, resolver.store.count)
        XCTAssertEqual(resolver.factories.count, 1)
        XCTAssertEqual(resolver.store.count, 1)
    }
    
    func testResolveSampleType_propertyWrapper_identifierAndParameters() {
        // GIVEN
        let resolver = SimpleResolver.sharedResolver
        let expectedFactoryParameters = ["someKey": "someValue"]
        var factoryClosureCallCount = 0
        let factory = Factory(type: SomeClass.self) { parameters, _ in
            guard let parameters else {
                XCTFail("unexpected")
                return
            }
            XCTAssertEqual(parameters as NSDictionary, expectedFactoryParameters as NSDictionary)
            factoryClosureCallCount += 1
            return SomeClass()
        }
        
        // We store a factory for a specific specialized type using an identifier
        let specialIdentifier = "special"
        let customIdentifier = "custom"
        
        try! resolver.store(factory: factory, forCustomTypeIdentifier: specialIdentifier)
        try! resolver.store(factory: factory, forCustomTypeIdentifier: customIdentifier)
        
        // WHEN
        let classWithServicies = AClassThatUsesComplexDI()
        
        // THEN
        XCTAssertFalse(classWithServicies.custom === classWithServicies.special,
                       "`custom` and `special` should resolve two distinct objects")
        XCTAssertEqual(factoryClosureCallCount, 2, "the factory closure should be called twice exactly")
        
        XCTAssertEqual(resolver.factories.count, resolver.store.count)
        XCTAssertEqual(resolver.factories.count, 2)
        XCTAssertEqual(resolver.store.count, 2)
    }
    
    func testResolveSampleType_propertyWrapper_chainedDependency_classes() {
        // GIVEN
        let resolver = SimpleResolver.sharedResolver
        let expectedObject = SomeClass()
        var factoryClosureCallCount = 0
        let factory = Factory(type: SomeClass.self) { _, _ in
            factoryClosureCallCount += 1
            return expectedObject
        }
        
        var dependentFactoryClosureCallCount = 0
        let dependentFactory = Factory(type: ClassWithSomeDependentType.self) { _, resolver in
            dependentFactoryClosureCallCount += 1
            
            do {
                let dependency = try resolver.resolve(type: SomeClass.self,
                                                      forCustomTypeIdentifier: nil,
                                                      factoryParameters: nil,
                                                      resolver: resolver)
                
                let resolved = ClassWithSomeDependentType(dependency: dependency)
                return resolved
            } catch {
                XCTFail("Unexpected resolution error:\(error)")
                return
            }
        }
        
        // Order of call to store does not matter, but should be done asap
        try! resolver.store(factory: dependentFactory)
        try! resolver.store(factory: factory)
        
        // WHEN
        let chain = AClassThatChainsDI()
        
        // THEN
        XCTAssertTrue(chain.injected.dependency === expectedObject,
                       "Resolution should provide the injected object with the correct dependency")
        XCTAssertEqual(factoryClosureCallCount, 1, "the closure should be called once exactly")
        XCTAssertEqual(dependentFactoryClosureCallCount, 1, "the closure should be called once exactly")
        
        XCTAssertEqual(resolver.factories.count, resolver.store.count)
        XCTAssertEqual(resolver.factories.count, 2)
        XCTAssertEqual(resolver.store.count, 2)
    }
    
    func testResolveSampleType_propertyWrapper_chainedDependency_struct() {
        // GIVEN
        let resolver = SimpleResolver.sharedResolver
        let expectedStruct = SomeStruct()
        var factoryClosureCallCount = 0
        let factory = Factory(type: SomeStruct.self) { _, _ in
            factoryClosureCallCount += 1
            return expectedStruct
        }
        
        var dependentFactoryClosureCallCount = 0
        let dependentFactory = Factory(type: StructWithSomeDependentType.self) { _, resolver in
            dependentFactoryClosureCallCount += 1
            
            do {
                let dependency = try resolver.resolve(type: SomeStruct.self,
                                                      forCustomTypeIdentifier: nil,
                                                      factoryParameters: nil,
                                                      resolver: resolver)
                
                let resolved = StructWithSomeDependentType(dependency: dependency)
                return resolved
            } catch {
                XCTFail("Unexpected resolution error:\(error)")
                return
            }
        }
        
        // Order of call to store does not matter, but should be done asap
        try! resolver.store(factory: dependentFactory)
        try! resolver.store(factory: factory)
        
        // WHEN
        var chain = StructThatChainsDI()
        
        // THEN
        XCTAssertEqual(chain.injected.dependency.identity, expectedStruct.identity,
                       "identity is expected to match")
        XCTAssertEqual(factoryClosureCallCount, 1, "the closure should be called once exactly")
        XCTAssertEqual(dependentFactoryClosureCallCount, 1, "the closure should be called once exactly")
        
        XCTAssertEqual(resolver.factories.count, resolver.store.count)
        XCTAssertEqual(resolver.factories.count, 2)
        XCTAssertEqual(resolver.store.count, 2)
    }
}

// MARK: - Helper Class

class SomeClass {}


/// A class with only one resolved property
class AClassThatUsesDI {
    
    init() {}
    
    @InjectService var injected: SomeClass
}

/// A class with one resolved property using `factoryParameters`
class AClassThatUsesFactoryParametersDI {
    
    init() {}
    
    @InjectService(factoryParameters: ["someKey":"someValue"]) var injected: SomeClass
    
}

/// A class with two resolved properties of the same type using `customTypeIdentifier`
class AClassThatUsesCustomIdentifiersDI {
    
    init() {}
    
    @InjectService(customTypeIdentifier: "specialIdentifier") var special: SomeClass
    
    @InjectService(customTypeIdentifier: "customIdentifier") var custom: SomeClass
    
}

/// A class with two resolved properties of the same type using `customTypeIdentifier` and  using `factoryParameters`
class AClassThatUsesComplexDI {
    
    init() {}
    
    @InjectService(customTypeIdentifier: "special",
                   factoryParameters: ["someKey":"someValue"]) var special: SomeClass
    
    @InjectService(customTypeIdentifier: "custom",
                   factoryParameters: ["someKey":"someValue"]) var custom: SomeClass
    
}

/// A class with only one resolved property
class AClassThatChainsDI {
    
    init() {}
    
    @InjectService var injected: ClassWithSomeDependentType
}

class ClassWithSomeDependentType {
    
    let dependency: SomeClass
    
    init(dependency: SomeClass) {
        self.dependency = dependency
    }
    
}

// MARK: - Helper Struct

struct SomeStruct {
    
    let identity: String = UUID().uuidString
    
}

/// A class with only one resolved property
struct StructThatChainsDI {
    
    @InjectService var injected: StructWithSomeDependentType
    
}

class StructWithSomeDependentType {
    
    let dependency: SomeStruct
    
    init(dependency: SomeStruct) {
        self.dependency = dependency
    }
    
}
