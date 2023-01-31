/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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
import kDriveCore
import RealmSwift
import InfomaniakDI

class UploadCountManager {
    @InjectService var uploadQueue: UploadQueue

    private let driveFileManager: DriveFileManager
    private let didUploadCountChange: () -> Void
    private let uploadCountThrottler = Throttler<Int>(timeInterval: 1, queue: .main)
    private let observeQueue = DispatchQueue(label: "com.infomaniak.drive.uploadThrottler", qos: .utility, autoreleaseFrequency: .workItem)

    private lazy var userId = driveFileManager.drive.userId
    private lazy var driveIds = [driveFileManager.drive.id] + DriveInfosManager.instance.getDrives(for: userId, sharedWithMe: true).map(\.id)

    public var uploadCount = 0

    private var uploadsObserver: NotificationToken?

    init(driveFileManager: DriveFileManager, didUploadCountChange: @escaping () -> Void) {
        self.driveFileManager = driveFileManager
        self.didUploadCountChange = didUploadCountChange
        updateUploadCount()
        observeUploads()
    }

    deinit {
        uploadsObserver?.invalidate()
    }

    @discardableResult
    func updateUploadCount() -> Int {
        uploadCount = uploadQueue.getUploadingFiles(userId: userId, driveIds: driveIds).count
        return uploadCount
    }

    private func observeUploads() {
        guard uploadsObserver == nil else { return }

        uploadCountThrottler.handler = { [weak self] newUploadCount in
            self?.uploadCount = newUploadCount
            self?.didUploadCountChange()
        }

        uploadsObserver = uploadQueue.getUploadingFiles(userId: userId, driveIds: driveIds).observe(on: observeQueue) { [weak self] change in
            switch change {
            case .initial(let results):
                self?.uploadCountThrottler.call(results.count)
            case .update(let results, deletions: _, insertions: _, modifications: _):
                self?.uploadCountThrottler.call(results.count)
            case .error(let error):
                print(error)
            }
        }
    }
}
