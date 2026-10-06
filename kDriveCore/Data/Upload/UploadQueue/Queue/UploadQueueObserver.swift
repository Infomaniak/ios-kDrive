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

public final class UploadQueueObserver {
    private var observation: NSKeyValueObservation?

    private let serialEventQueue = DispatchQueue(
        label: "com.infomaniak.drive.upload-queue-observer.event.\(UUID().uuidString)",
        qos: .default
    )

    var uploadQueue: UploadQueue
    weak var queueStateDelegate: UploadQueueStateDelegate?

    init(uploadQueue: UploadQueue, queueStateDelegate: UploadQueueStateDelegate?) {
        self.uploadQueue = uploadQueue
        self.queueStateDelegate = queueStateDelegate

        setupObservation()
    }

    private func setupObservation() {
        observation = uploadQueue.operationQueue.observe(\.operationCount, options: [
            .new,
            .old
        ]) { [weak self] _, change in
            guard let self else { return }
            self.serialEventQueue.async {
                self.operationCountDidChange(previousCount: change.oldValue, newCount: change.newValue)
            }
        }
    }

    private func operationCountDidChange(previousCount: Int?, newCount: Int?) {
        guard let newCount else {
            queueStateDelegate?.operationQueueBecameEmpty()
            return
        }

        guard let previousCount else {
            queueStateDelegate?.operationQueueNoLongerEmpty()
            return
        }

        if newCount == 0 && previousCount > 0 {
            queueStateDelegate?.operationQueueBecameEmpty()
        } else if previousCount == 0 && newCount > 0 {
            queueStateDelegate?.operationQueueNoLongerEmpty()
        }
    }
}
