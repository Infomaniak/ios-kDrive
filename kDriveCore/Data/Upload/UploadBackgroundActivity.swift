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

@MainActor
final class UploadBackgroundActivity {
    private struct Activity {
        let id: UUID
        let value: any ExpiringActivityable
        let delegate: ExpirationDelegate
    }

    private let makeActivity: (ExpiringActivityDelegate) -> any ExpiringActivityable
    private let pauseUploads: @MainActor () async -> Void
    private var activity: Activity?
    private var isExpiring = false

    init(
        makeActivity: @escaping (ExpiringActivityDelegate) -> any ExpiringActivityable = {
            ExpiringActivity(id: "UploadQueues", delegate: $0)
        },
        pauseUploads: @escaping @MainActor () async -> Void
    ) {
        self.makeActivity = makeActivity
        self.pauseUploads = pauseUploads
    }

    deinit {
        activity?.value.endAll()
    }

    func update(hasWork: Bool) {
        guard !isExpiring else { return }
        guard hasWork else {
            activity?.value.endAll()
            activity = nil
            return
        }
        guard activity == nil else { return }

        let id = UUID()
        let delegate = ExpirationDelegate { [weak self] in
            Task { @MainActor in await self?.expire(id: id) }
        }
        let value = makeActivity(delegate)
        activity = Activity(id: id, value: value, delegate: delegate)
        value.start()
    }

    private func expire(id: UUID) async {
        guard let activity, activity.id == id, !isExpiring else { return }
        isExpiring = true
        await pauseUploads()
        activity.value.endAll()
        self.activity = nil
        isExpiring = false
    }
}

private final class ExpirationDelegate: ExpiringActivityDelegate {
    private let onExpiration: @Sendable () -> Void

    init(onExpiration: @escaping @Sendable () -> Void) {
        self.onExpiration = onExpiration
    }

    func backgroundActivityExpiring() {
        onExpiration()
    }
}
