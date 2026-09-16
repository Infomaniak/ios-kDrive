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
@testable import kDrive
import kDriveCore
import RealmSwift
import Testing
import UIKit

@MainActor
@Suite
struct UTUploadQueueFolders {
    @Test func missingFolderLoadsWithoutPoppingAndRequestsAreDeduplicated() async throws {
        let fixture = try Fixture()
        defer { fixture.resolver.finish() }
        try await waitUntil { fixture.resolver.requests.count == 1 }

        #expect(fixture.navigation.topViewController === fixture.controller)
        #expect(fixture.rowCount == 0)
        #expect(fixture.resolver.requests.first?.id == 42)
        #expect(fixture.resolver.requests.first?.driveId == 7)

        try fixture.realm.write { fixture.upload.name = "updated.jpg" }
        await fixture.realmNotification()
        #expect(fixture.resolver.requests.count == 1)

        fixture.resolver.finish()
        try await waitUntil { fixture.rowCount == 1 }
        #expect(fixture.navigation.topViewController === fixture.controller)
        #expect(fixture.resolver.requests.count == 1)
    }

    @Test func failedFolderFetchDoesNotPopPendingUploads() async throws {
        let fixture = try Fixture()
        defer { fixture.resolver.finish() }
        try await waitUntil { fixture.resolver.requests.count == 1 }
        fixture.resolver.finish(error: DriveError.objectNotFound)
        try fixture.realm.write { fixture.upload.name = "updated.jpg" }
        await fixture.realmNotification()

        #expect(fixture.navigation.topViewController === fixture.controller)
        #expect(fixture.rowCount == 0)
        #expect(fixture.resolver.requests.count == 1)
    }

    @Test func completingUploadsDuringFetchDoesNotRestoreStaleRowsOrPopAnotherScreen() async throws {
        let fixture = try Fixture()
        defer { fixture.resolver.finish() }
        try await waitUntil { fixture.resolver.requests.count == 1 }
        try fixture.realm.write { fixture.upload.uploadDate = Date() }
        try await waitUntil { fixture.navigation.topViewController === fixture.root }

        fixture.resolver.finish()
        await fixture.realmNotification()
        #expect(fixture.navigation.topViewController === fixture.root)
        #expect(fixture.rowCount == 0)
        #expect(fixture.navigation.viewControllers.count == 1)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition())
    }
}

@MainActor
private final class Fixture {
    let realm: Realm
    let upload = UploadFile()
    let resolver = ControlledFolderResolver()
    let controller = UploadQueueFoldersViewController(style: .plain)
    let root = UIViewController()
    let navigation: UINavigationController

    var rowCount: Int { controller.tableView(controller.tableView, numberOfRowsInSection: 0) }

    init() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
        navigation = UINavigationController(rootViewController: root)
        upload.driveId = 7
        upload.parentDirectoryId = 42
        upload.name = "photo.jpg"
        try realm.write { realm.add(upload) }
        navigation.pushViewController(controller, animated: false)
        controller.loadViewIfNeeded()
        controller.observeUploads(realm.objects(UploadFile.self).filter("uploadDate == nil"), folderResolver: resolver)
    }

    /// Wait for Realm's next delivery on the main queue, then let the folder task update the UI.
    func realmNotification() async {
        await withCheckedContinuation { continuation in
            var token: NotificationToken?
            token = realm.objects(UploadFile.self).observe(on: .main) { _ in
                token?.invalidate()
                token = nil
                continuation.resume()
            }
        }
        await Task.yield()
    }
}

@MainActor
private final class ControlledFolderResolver: UploadFolderResolving {
    private(set) var requests: [ProxyFile] = []
    private var continuation: CheckedContinuation<Void, any Error>?
    private var folder: File?

    func cachedFolder(_ file: ProxyFile) -> File? { folder }

    func loadFolder(_ file: ProxyFile) async throws {
        requests.append(file)
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func finish(error: (any Error)? = nil) {
        guard let continuation else { return }
        self.continuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            folder = File(id: 42, name: "Photo backup")
            continuation.resume()
        }
    }
}
