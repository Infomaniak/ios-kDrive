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

final class DynamicIslandUploadProgressTracker: ObservableObject {
    @Published var fractionCompleted: Double = 0

    @LazyInjectService var uploadDataSource: UploadServiceDataSourceable

    private var realmObservationToken: NotificationToken?
    private(set) var totalUploadCount = 0
    private(set) var progressUploading = 0
    private var progressChunkUploading = 0.0
    private var cancellables: Set<AnyCancellable> = []
    private var observationCancellables: Set<AnyCancellable> = []
    private var overallProgress: Progress?
    private var lastUpdateTime: ContinuousClock.Instant?
    private var clock = ContinuousClock()

    private let queueActivitySubject = CurrentValueSubject<(global: Bool, photo: Bool), Never>((false, false))

    private let scale = 100.0

    static let photoAssetPredicate = NSPredicate(format: "rawType = %@", argumentArray: [UploadFileType.phAsset.rawValue])
    static let globalAssetPredicate = NSPredicate(format: "rawType != %@", argumentArray: [UploadFileType.phAsset.rawValue])

    init() {
        setupQueueActivityObservation()
    }

    private func setupQueueActivityObservation() {
        queueActivitySubject
            .removeDuplicates { $0 == $1 }
            .receive(on: RunLoop.main)
            .sink { [weak self] global, photo in
                guard let self else { return }
                if global || photo {
                    self.startObservation(global: global, photo: photo)
                } else {
                    self.stopObservation()
                }
            }
            .store(in: &cancellables)
    }

    private func startObservation(global: Bool, photo: Bool) {
        let optionalPredicate: NSPredicate? = uploadingFilesObserverOption(global: global, photo: photo)

        realmObservationToken?.invalidate()
        observationCancellables.removeAll()

        totalUploadCount = uploadDataSource.getUploadingFiles(optionalPredicate: optionalPredicate).count
        lastUpdateTime = clock.now

        overallProgress = Progress(totalUnitCount: Int64(totalUploadCount))
        overallProgress?
            .publisher(for: \.fractionCompleted)
            .throttle(for: .milliseconds(50), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] fractionCompleted in
                self?.fractionCompleted = fractionCompleted
                self?.keepAlive()
            }
            .store(in: &observationCancellables)

        realmObservationToken = uploadDataSource.getUploadingFiles(optionalPredicate: optionalPredicate)
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
        observationCancellables.removeAll()
        overallProgress = nil
    }

    private func uploadingFilesObserverOption(global: Bool, photo: Bool) -> NSPredicate? {
        switch (global, photo) {
        case (true, true): return nil
        case (true, false): return Self.globalAssetPredicate
        case (false, true): return Self.photoAssetPredicate
        default: return nil
        }
    }

    func updateQueueActivity(globalQueueActive: Bool, photoQueueActive: Bool) {
        queueActivitySubject.send((global: globalQueueActive, photo: photoQueueActive))
    }

    func keepAlive() {
        guard let lastUpdateTime,
              let overallProgress,
              (clock.now - lastUpdateTime) > .milliseconds(50)
        else { return }
        overallProgress.totalUnitCount = Int64(Double(totalUploadCount) * scale)
        overallProgress.completedUnitCount = Int64((progressChunkUploading + Double(progressUploading)) * scale)
    }

    func reset() {
        totalUploadCount = 0
        progressUploading = 0
        fractionCompleted = 0
    }
}
