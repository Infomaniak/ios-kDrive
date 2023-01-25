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

@testable import kDriveCore
import XCTest

class MCKSomeType {}


class AClassThatUsesDI {
    
    init() {}
    
    @InjectService var injected: MCKSomeType
    
}

/// Integration Tests of the Simple DI mechanism
final class ITSimpleReslover: XCTestCase {
    
    override func setUp() {
        // NOOP
    }

    override func tearDown() {
        SimpleResolver.sharedResolver.removeAll()
    }
    
    // MARK: - resolve(type: forCustomTypeIdentifier: resolver:)
    
    func testResolveSampleType_callExplicitResolve() {
        // GIVEN
        let resolver = SimpleResolver.sharedResolver
        let expectedObject = MCKSomeType()
        var factoryClosureCallCount = 0
        let factory = Factory(type: MCKSomeType.self) { _, _ in
            factoryClosureCallCount += 1
            return expectedObject
        }
        
        try! resolver.store(factory: factory)
        
        // WHEN
        do {
            let resolved = try resolver.resolve(type: MCKSomeType.self,
                                                forCustomTypeIdentifier: nil,
                                                resolver: resolver)
            
            // THEN
            XCTAssertTrue(resolved === expectedObject, "identity of resolved object should match")
            XCTAssertEqual(factoryClosureCallCount, 1, "the factory closure should be called once exactly")
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }
    
    func testResolveSampleType_propertyWrapper() {
        // GIVEN
        
        // WHEN

        // THEN
    }
    
    func testResolveSampleType_propertyWrapper_withCustomParameters() {
        // GIVEN
        
        // WHEN

        // THEN
    }
}
