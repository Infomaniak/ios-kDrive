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
import InfomaniakCore
@testable import kDriveCore
import Testing

@Suite
@MainActor
struct UTUploadBackgroundActivity {
    @Test func sharesProtectionAndRestartsAfterIdle() {
        var activities: [TestActivity] = []
        let owner = UploadBackgroundActivity(makeActivity: { delegate in
            let activity = TestActivity(delegate: delegate)
            activities.append(activity)
            return activity
        }, pauseUploads: {})

        owner.update(hasWork: true)
        owner.update(hasWork: true)
        #expect(activities.count == 1)
        #expect(activities[0].starts == 1)
        owner.update(hasWork: false)
        #expect(activities[0].ends == 1)
        owner.update(hasWork: true)
        #expect(activities.count == 2)
        owner.update(hasWork: false)
    }

    @Test func expirationWaitsForCleanupAndIgnoresDuplicates() async {
        var activities: [TestActivity] = []
        var cleanup: CheckedContinuation<Void, Never>?
        var cleanupCount = 0
        let owner = UploadBackgroundActivity(makeActivity: { delegate in
            let activity = TestActivity(delegate: delegate)
            activities.append(activity)
            return activity
        }, pauseUploads: {
            cleanupCount += 1
            await withCheckedContinuation { cleanup = $0 }
        })

        owner.update(hasWork: true)
        activities[0].delegate?.backgroundActivityExpiring()
        await drainCallbacks()
        #expect(cleanupCount == 1)
        #expect(activities[0].ends == 0)

        activities[0].delegate?.backgroundActivityExpiring()
        owner.update(hasWork: false)
        await drainCallbacks()
        #expect(cleanupCount == 1)
        #expect(activities[0].ends == 0)

        cleanup?.resume()
        await drainCallbacks()
        #expect(activities[0].ends == 1)

        owner.update(hasWork: true)
        #expect(activities.count == 2)
        activities[0].delegate?.backgroundActivityExpiring()
        await drainCallbacks()
        #expect(cleanupCount == 1)
        #expect(activities[1].ends == 0)
        owner.update(hasWork: false)
    }

    private func drainCallbacks() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

private final class TestActivity: ExpiringActivityable {
    var starts = 0
    var ends = 0
    var shouldTerminate = false
    let delegate: ExpiringActivityDelegate?

    init(delegate: ExpiringActivityDelegate) {
        self.delegate = delegate
    }

    init(id: String, qos: DispatchQoS, delegate: ExpiringActivityDelegate?) {
        self.delegate = delegate
    }

    convenience init(id: String, delegate: ExpiringActivityDelegate?) {
        self.init(id: id, qos: .default, delegate: delegate)
    }

    func start() { starts += 1 }
    func endAll() { ends += 1 }
}
