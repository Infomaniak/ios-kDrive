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

import InfomaniakCore
@testable import kDriveCore
import XCTest

final class UTDownloadQueueObservation: XCTestCase {
    private final class Observer {}

    override func setUp() {
        super.setUp()
        TestTargetAssemblyHelper.clearRegisteredTypes()
        _ = TestTargetAssemblyHelper(configuration: .minimal)
    }

    func testFileDownloadObserverCanCancelWhileNotificationIsPublished() {
        let downloadQueue = DownloadQueue()
        let observer = Observer()
        var token: ObservationToken?
        var notificationCount = 0

        token = downloadQueue.observeFileDownloaded(observer, fileId: 42) { _, _ in
            notificationCount += 1
            token?.cancel()
        }

        downloadQueue.publishFileDownloaded(fileId: 42, error: nil)
        downloadQueue.publishFileDownloaded(fileId: 42, error: nil)

        XCTAssertEqual(notificationCount, 1)
    }
}
