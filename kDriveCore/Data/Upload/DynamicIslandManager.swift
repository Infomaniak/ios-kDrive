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
    private var progessUploading: Int
    private var cancellables: Set<AnyCancellable> = []
    private var overallProgress: Progress?
    private var lastUpdateTime: ContinuousClock.Instant?
    private var clock = ContinuousClock()

    private var globalQueueActive = false
    private var photoQueueActive = false
    private var changeQueueObserver = false
    private var isObserving = false

    static let photoAssetPredicate = NSPredicate(format: "rawType = %@", argumentArray: [UploadFileType.phAsset.rawValue])
    static let globalAssetPredicate = NSPredicate(format: "rawType != %@", argumentArray: [UploadFileType.phAsset.rawValue])

    var driveFileManager: DriveFileManager? {
        didSet {
            refreshObservation()
        }
    }

    init(driveFileManager: DriveFileManager?) {
        self.driveFileManager = driveFileManager
        totalUploadCount = 0
        progessUploading = 0
        refreshObservation()
    }

    func setup() {
        guard driveFileManager == nil else { return }
        driveFileManager = accountManager.currentDriveFileManager
    }

    private func refreshObservation() {
        let shouldObserve = globalQueueActive || photoQueueActive
        if !shouldObserve {
            if isObserving {
                stopObservation()
                isObserving = false
            }
            return
        }
        if !isObserving || changeQueueObserver {
            startObservation()
            isObserving = true
        }
    }

    private func startObservation() {
        guard let driveFileManager else { return }
        let driveId = driveFileManager.driveId

        let optionalPredicate: NSPredicate? = uploadingFilesObserverOption()

        realmObservationToken?.invalidate()
        cancellables.removeAll()

        totalUploadCount = uploadDataSource.getUploadingFiles(
            userId: accountManager.currentUserId,
            driveIds: [driveId],
            optionalPredicate: optionalPredicate
        ).count

        lastUpdateTime = clock.now

        overallProgress = Progress(totalUnitCount: Int64(totalUploadCount))
        overallProgress?
            .publisher(for: \.fractionCompleted)
            .throttle(for: .milliseconds(50), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] fractionCompleted in
                self?.fractionCompleted = fractionCompleted
                self?.keepAlive()
            }
            .store(in: &cancellables)

        realmObservationToken = uploadDataSource.getUploadingFiles(
            userId: accountManager.currentUserId,
            driveIds: [driveId],
            optionalPredicate: optionalPredicate
        )
        .observe(on: .main) { [weak self] change in
            guard let self else { return }

            self.lastUpdateTime = clock.now

            switch change {
            case .initial(let results), .update(let results, deletions: _, insertions: _, modifications: _):
                let remaining = results.count
                totalUploadCount = max(totalUploadCount, remaining + progessUploading)
                progessUploading = totalUploadCount - remaining

                let percentOfProgress = totalUploadCount > 0 ? Double(progessUploading) / Double(totalUploadCount) : 0
                let completedCount = Int64(percentOfProgress * Double(totalUploadCount))

                self.overallProgress?.totalUnitCount = Int64(totalUploadCount)
                self.overallProgress?.completedUnitCount = completedCount
            case .error:
                self.overallProgress?.completedUnitCount = 0
            }
        }
    }

    private func stopObservation() {
        realmObservationToken?.invalidate()
        realmObservationToken = nil
        cancellables.removeAll()
        overallProgress = nil
    }

    private func uploadingFilesObserverOption() -> NSPredicate? {
        if globalQueueActive && photoQueueActive {
            return nil
        } else {
            if !globalQueueActive {
                return DynamicIslandManager.photoAssetPredicate
            } else {
                return DynamicIslandManager.globalAssetPredicate
            }
        }
    }

    func updateQueueActivity(globalQueueActive: Bool, photoQueueActive: Bool) {
        if globalQueueActive != self.globalQueueActive || photoQueueActive != self.photoQueueActive {
            changeQueueObserver = true
        }

        self.globalQueueActive = globalQueueActive
        self.photoQueueActive = photoQueueActive

        refreshObservation()
    }

    func keepAlive() {
        guard let lastUpdateTime else { return }
        let delay = clock.now - lastUpdateTime
        if delay > .milliseconds(50) {
            let percentOfProgress = totalUploadCount > 0 ? Double(progessUploading) / Double(totalUploadCount) : 0
            let completedCount = Int64(percentOfProgress * Double(totalUploadCount))

            overallProgress?.totalUnitCount = Int64(totalUploadCount)
            overallProgress?.completedUnitCount = completedCount
        }
    }

    func getTotalUploadCount() -> Int {
        return totalUploadCount
    }

    func reset() {
        totalUploadCount = 0
        progessUploading = 0
        fractionCompleted = 0
    }
}
