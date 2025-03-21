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

public class UploadQueueObserver: NSObject {
    private var previousCount: Int?
    private var observation: NSKeyValueObservation?

    private let serialEventQueue = DispatchQueue(
        label: "com.infomaniak.drive.upload-queue-observer.event.\(UUID().uuidString)",
        qos: .default
    )

    var uploadQueue: UploadQueue
    weak var delegate: UploadQueueDelegate?

    init(uploadQueue: UploadQueue, delegate: UploadQueueDelegate?) {
        self.uploadQueue = uploadQueue
        self.delegate = delegate
        super.init()

        setupObservation()
    }

    private func setupObservation() {
        observation = uploadQueue.operationQueue.observe(\.operationCount, options: [
            .new,
            .old
        ]) { [weak self] _, change in
            guard let self else { return }
            self.serialEventQueue.async {
                guard let newCount = change.newValue else { return }

                defer { self.previousCount = newCount }

                guard let previousCount = self.previousCount else {
                    self.delegate?.operationQueueNoLongerEmpty(self.uploadQueue)
                    return
                }

                guard previousCount != newCount else {
                    return
                }

                if newCount == 0 {
                    self.delegate?.operationQueueBecameEmpty(self.uploadQueue)
                } else if previousCount == 0 && newCount > 0 {
                    self.delegate?.operationQueueNoLongerEmpty(self.uploadQueue)
                }
            }
        }
    }
}
