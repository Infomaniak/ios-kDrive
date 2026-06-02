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

import Combine
import Foundation
import InfomaniakDI
import RealmSwift

final class DynamicIslandManager: ObservableObject {
    @Published var fractionCompleted: Double = 0

    @LazyInjectService var uploadService: UploadServiceable
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var uploadDataSource: UploadServiceDataSourceable

    private var realmObservationToken: NotificationToken?
    private var totalUploadCount: Int
    private var cancellables: Set<AnyCancellable> = []
    private var overallProgress: Progress?

    var driveFileManager: DriveFileManager? {
        didSet {
            initObservation()
        }
    }

    init(driveFileManager: DriveFileManager?) {
        self.driveFileManager = driveFileManager
        totalUploadCount = 0
        initObservation()
    }

    func setup() {
        guard driveFileManager == nil else { return }
        driveFileManager = accountManager.currentDriveFileManager
    }

    private func initObservation() {
        guard let driveFileManager else { return }
        let driveId = driveFileManager.driveId

        realmObservationToken?.invalidate()
        cancellables.removeAll()

        // TODO: totalUploadCount tracks the number of files currently uploading at a given moment. During a large sync, this number may rise, but it is not currently taken into account.
        totalUploadCount = uploadDataSource.getUploadingFiles(userId: accountManager.currentUserId, driveIds: [driveId]).count

        overallProgress = Progress(totalUnitCount: Int64(totalUploadCount))
        overallProgress?
            .publisher(for: \.fractionCompleted)
            .throttle(for: .milliseconds(500), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] fractionCompleted in
                self?.fractionCompleted = fractionCompleted
            }
            .store(in: &cancellables)

        // TODO: The calculations aren't accurate, but they let you see the upload progress
        realmObservationToken = uploadDataSource.getUploadingFiles(userId: accountManager.currentUserId, driveIds: [driveId])
            .observe(on: .main) { [weak self] change in
                guard let self else { return }
                switch change {
                case .initial(let results), .update(let results, deletions: _, insertions: _, modifications: _):
                    let remaining = results.count
                    let completed = max(0, self.totalUploadCount - remaining)
                    self.overallProgress?.completedUnitCount = Int64(completed)
                case .error:
                    self.overallProgress?.completedUnitCount = 0
                }
            }
    }
}
