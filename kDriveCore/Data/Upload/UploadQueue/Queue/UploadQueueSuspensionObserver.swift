/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

public final class UploadQueueSuspensionObserver {
    private var observation: NSKeyValueObservation?

    private let serialEventQueue = DispatchQueue(
        label: "com.infomaniak.drive.upload-queue-suspension-observer.event.\(UUID().uuidString)",
        qos: .default
    )

    var uploadQueue: UploadQueue
    weak var delegate: UploadQueueDelegate?

    init(uploadQueue: UploadQueue, delegate: UploadQueueDelegate?) {
        self.uploadQueue = uploadQueue
        self.delegate = delegate

        setupObservation()
    }

    func setupObservation() {
        observation = uploadQueue.operationQueue.observe(\.isSuspended, options: [.new, .old]) { [weak self] _, change in
            guard let self else { return }
            self.serialEventQueue.async {
                self.suspendStateDidChange(previousIsSuspend: change.oldValue, newIsSuspend: change.newValue)
            }
        }
    }

    func suspendStateDidChange(previousIsSuspend: Bool?, newIsSuspend: Bool?) {
        guard let currentIsSuspend = newIsSuspend ?? previousIsSuspend else {
            return
        }

        guard let previousIsSuspend else {
            delegate?.operationQueueNotSuspend(uploadQueue)
            if currentIsSuspend {
                delegate?.operationQueueBecameSuspend(uploadQueue)
            } else {
                delegate?.operationQueueNotSuspend(uploadQueue)
            }
            return
        }

        if currentIsSuspend {
            delegate?.operationQueueBecameSuspend(uploadQueue)
        } else if previousIsSuspend && !currentIsSuspend {
            delegate?.operationQueueNotSuspend(uploadQueue)
        }
    }
}
