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

import Combine
import Foundation
import InfomaniakDI
import kDriveCore
import RealmSwift

final class UploadCountManager {
    @LazyInjectService var uploadDataSource: UploadServiceDataSourceable
    @LazyInjectService var driveInfosManager: DriveInfosManager

    private let driveFileManager: DriveFileManager
    private let didUploadCountChange: () -> Void

    /// Something to debounce upload count events
    private let uploadCountSubject = PassthroughSubject<Int, Never>()
    private var uploadCountObserver: AnyCancellable?

    private let observeQueue = DispatchQueue(label: "com.infomaniak.drive.uploadThrottler",
                                             qos: .utility, autoreleaseFrequency: .workItem)

    private lazy var userId = driveFileManager.drive.userId
    private lazy var driveIds = [driveFileManager.driveId] + driveInfosManager
        .getDrives(for: userId, sharedWithMe: true).map(\.id)

    public var uploadCount = 0

    private var uploadsObserver: NotificationToken?

    init(driveFileManager: DriveFileManager, didUploadCountChange: @escaping () -> Void) {
        self.driveFileManager = driveFileManager
        self.didUploadCountChange = didUploadCountChange
        uploadCountObserver = uploadCountSubject
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] newUploadCount in
                self?.uploadCount = newUploadCount
                self?.didUploadCountChange()
            }

        updateUploadCount()
        observeUploads()
    }

    deinit {
        uploadCountObserver?.cancel()
        uploadsObserver?.invalidate()
    }

    @discardableResult
    func updateUploadCount() -> Int {
        uploadCount = uploadDataSource.getUploadingFiles(userId: userId, driveIds: driveIds).count
        return uploadCount
    }

    private func observeUploads() {
        guard uploadsObserver == nil else { return }

        uploadsObserver = uploadDataSource
            .getUploadingFiles(userId: userId, driveIds: driveIds)
            .observe(on: observeQueue) { [weak self] change in
                guard let self else {
                    return
                }

                switch change {
                case .initial(let results), .update(let results, deletions: _, insertions: _, modifications: _):
                    uploadCountSubject.send(results.count)
                case .error(let error):
                    print(error)
                }
            }
    }
}
