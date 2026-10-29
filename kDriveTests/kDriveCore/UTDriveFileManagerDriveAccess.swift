/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation
import InfomaniakCoreDB
@testable import InfomaniakDI
@testable import kDriveCore
import RealmSwift
import Testing

extension ResolverTests {
    @Suite
    @MainActor
    struct UTDriveFileManagerDriveAccess {
        @Test(arguments: [false, true])
        func refreshesMetadataAndFallsBackToInitialFrozenDrive(customPrimaryKey: Bool) throws {
            let fixture = try DriveAccessFixture(customPrimaryKey: customPrimaryKey)
            defer { fixture.tearDown() }
            let manager = fixture.manager
            let initialDrive = manager.drive
            #expect(initialDrive.isFrozen)

            try fixture.realm.write {
                fixture.liveDrive.name = "Updated drive"
                fixture.liveDrive.usedSize = 42
            }

            let updatedDrive = manager.drive
            #expect(updatedDrive.isFrozen)
            #expect(updatedDrive.objectId == fixture.liveDrive.objectId)
            #expect(updatedDrive.name == "Updated drive")
            #expect(updatedDrive.usedSize == 42)
            #expect(initialDrive.name == "Initial drive")

            try fixture.realm.write { fixture.realm.delete(fixture.liveDrive) }

            let fallback = manager.drive
            #expect(fallback.isFrozen)
            #expect(!fallback.isInvalidated)
            #expect(fallback.name == "Initial drive")
            #expect(fallback.usedSize == 0)
            #expect(manager.driveId == initialDrive.id)
        }

        @Test func concurrentReadsReturnFrozenSnapshotsAndStableIdentity() async throws {
            let fixture = try DriveAccessFixture(customPrimaryKey: false)
            defer { fixture.tearDown() }
            let manager = fixture.manager
            let expectedId = manager.driveId
            let expectedObjectId = manager.drive.objectId

            // Exercise the shared getter from multiple executor threads; also run under Thread Sanitizer.
            await withTaskGroup(of: Void.self) { group in
                for _ in 0 ..< 8 {
                    group.addTask {
                        for _ in 0 ..< 100 {
                            autoreleasepool {
                                let snapshot = manager.drive
                                #expect(snapshot.isFrozen)
                                #expect(snapshot.objectId == expectedObjectId)
                                #expect(snapshot.id == expectedId)
                                #expect(manager.driveId == expectedId)
                            }
                        }
                    }
                }
            }
        }
    }
}

@MainActor
private final class DriveAccessFixture {
    let realm: Realm
    let liveDrive: Drive
    let manager: DriveFileManager
    private let savedFactories: [String: Factoryable]
    private let savedServices: [String: Any]

    init(customPrimaryKey: Bool) throws {
        let configuration = Realm.Configuration(inMemoryIdentifier: UUID().uuidString,
                                                objectTypes: DriveInfosManager.realmConfiguration.objectTypes)
        let realm = try Realm(configuration: configuration)
        let liveDrive = Drive()
        liveDrive.id = Int.random(in: 100_000 ... 999_999_999)
        liveDrive.userId = liveDrive.id
        liveDrive.name = "Initial drive"
        if customPrimaryKey {
            liveDrive.objectId = "public-share-test"
        }
        try realm.write { realm.add(liveDrive) }
        self.realm = realm
        self.liveDrive = liveDrive

        let resolver = SimpleResolver.sharedResolver
        savedFactories = resolver.factories
        savedServices = resolver.store
        resolver.removeAll()
        _ = TestTargetAssemblyHelper(configuration: .minimal)
        let database = TransactionExecutor(realmAccessible: RealmAccessor(
            realmURL: nil, realmConfiguration: configuration, excludeFromBackup: false
        ))
        resolver.store(factory: Factory(type: Transactionable.self) { _, _ in database },
                       forCustomTypeIdentifier: kDriveDBID.driveInfo)

        // A live input must be frozen before the manager retains it as a cross-thread fallback.
        manager = DriveFileManager(drive: liveDrive, apiFetcher: DriveApiFetcher())
    }

    func tearDown() {
        _ = try? Realm.deleteFiles(for: manager.realmConfiguration)
        let resolver = SimpleResolver.sharedResolver
        resolver.removeAll()
        resolver.factories = savedFactories
        resolver.store = savedServices
    }
}
