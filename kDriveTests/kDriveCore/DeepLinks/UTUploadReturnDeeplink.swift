/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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
@testable import InfomaniakDI
@testable import kDriveCore
import Testing

extension ResolverTests {
    @Suite
    @MainActor
    struct UTUploadReturnDeeplink {
        @Test(arguments: [
            ("kdrive://uploads", true),
            ("https://uploads", false),
            ("kdrive://uploads/other", false),
            ("kdrive://", false)
        ])
        func rebuildsQueueOnlyForUploadReturn(urlString: String, expectedRebuild: Bool) async throws {
            let savedFactories = SimpleResolver.sharedResolver.factories
            let savedServices = SimpleResolver.sharedResolver.store
            defer {
                SimpleResolver.sharedResolver.factories = savedFactories
                SimpleResolver.sharedResolver.store = savedServices
            }

            SimpleResolver.sharedResolver.store.removeAll()
            let uploadService = UploadReturnServiceSpy()
            SimpleResolver.sharedResolver.store(factory: Factory(type: UploadServiceable.self) { _, _ in
                uploadService
            })

            let url = try #require(URL(string: urlString))
            let handled = await DeeplinkParser(sharedContainerURL: nil).parse(url: url)

            #expect(handled == expectedRebuild)
            #expect(uploadService.rebuildCount == (expectedRebuild ? 1 : 0))
        }
    }
}

private final class UploadReturnServiceSpy: UploadServiceable {
    var rebuildCount = 0
    var isSuspended = false
    var operationCount = 0

    func rebuildUploadQueue() { rebuildCount += 1 }
    func blockingRebuildUploadQueue() {}
    func suspendAllOperations() {}
    func pauseForBackgroundExpiration() async {}
    func resumeAllOperations() {}
    func waitForCompletion(_ completionHandler: @escaping () -> Void) { completionHandler() }
    func waitForCompletionForActiveQueues(_ completionHandler: @escaping () -> Void) { completionHandler() }
    func retry(_ uploadFileId: String) {}
    func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {}
    func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {}
    func cancelAnyPhotoSync(includingBlockedUploadsForUserId userId: Int?) async throws {}
    func blockUploadsForAuthentication(userId: Int) throws {}
    func resumeUploadsAfterAuthentication(userId: Int) async {}
    func rescheduleRunningOperations() {}
    func cancel(uploadFileId: String) -> Bool { false }
    func cleanNetworkAndLocalErrorsForAllOperations() {}
    func updateQueueSuspension() {}
}
