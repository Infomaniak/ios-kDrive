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
    private var progressUploading: Int
    private var progressChunkUploading = 0.0
    private var cancellables: Set<AnyCancellable> = []
    private var overallProgress: Progress?
    private var lastUpdateTime: ContinuousClock.Instant?
    private var clock = ContinuousClock()

    private var globalQueueActive = false
    private var photoQueueActive = false
    private var changeQueueObserver = false
    private var isObserving = false

    private let scale = 100.0

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
        progressUploading = 0
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
            guard driveFileManager != nil else { return }
            startObservation()
            isObserving = true
            changeQueueObserver = false
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
                totalUploadCount = max(totalUploadCount, remaining + progressUploading)
                progressUploading = totalUploadCount - remaining

                progressChunkUploading = results.compactMap(\.progress).filter { $0 > 0 }.reduce(0, +)

                self.overallProgress?.totalUnitCount = Int64(Double(totalUploadCount) * scale)
                self.overallProgress?.completedUnitCount = Int64((progressChunkUploading + Double(progressUploading)) * scale)
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
        switch (globalQueueActive, photoQueueActive) {
        case (true, true):
            return nil
        case (true, false):
            return DynamicIslandManager.globalAssetPredicate
        case(false, true):
            return DynamicIslandManager.photoAssetPredicate
        default:
            return nil
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
            overallProgress?.totalUnitCount = Int64(Double(totalUploadCount) * scale)
            overallProgress?.completedUnitCount = Int64((progressChunkUploading + Double(progressUploading)) * scale)
        }
    }

    func getTotalUploadCount() -> Int {
        return totalUploadCount
    }

    func getProgressUploading() -> Int {
        return progressUploading
    }

    func reset() {
        totalUploadCount = 0
        progressUploading = 0
        fractionCompleted = 0
    }
}
