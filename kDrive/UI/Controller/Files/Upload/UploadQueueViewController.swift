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

import CocoaLumberjackSwift
import DifferenceKit
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

typealias UploadFileDisplayed = CornerCellContainer<UploadFile>

final class UploadQueueViewController: UIViewController {
    private let errorFile = UploadFileDisplayed(isFirstInList: true, isLastInList: true, content: UploadFile())
    private var isWifiOnly = false
    private var wifiOnlyNotificationToken: NotificationToken?

    enum SectionModel: Differentiable {
        case error, files
    }

    @IBOutlet var tableView: UITableView!
    @IBOutlet var retryButton: UIBarButtonItem!
    @IBOutlet var cancelButton: UIBarButtonItem!

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var uploadService: UploadServiceable
    @LazyInjectService var uploadDataSource: UploadServiceDataSourceable
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploader

    var currentDirectory: File!
    private var frozenUploadingFiles = [UploadFileDisplayed]()
    private lazy var sections = buildSections(files: [UploadFileDisplayed]())
    private var observedFilesNotificationToken: NotificationToken?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let liveSettings = photoLibraryUploader.liveSettings {
            isWifiOnly = liveSettings.isWifiOnly
            wifiOnlyNotificationToken = liveSettings.observe(keyPaths: ["syncMode"], on: .main) { [weak self] change in
                guard let self else {
                    return
                }

                switch change {
                case .change(let object, _):
                    guard let syncSettings = object as? PhotoSyncSettings else { return }
                    self.isWifiOnly = syncSettings.isWifiOnly
                case .error(let error):
                    DDLogError("[Realm Observation] Error sync settings \(error)")
                case .deleted:
                    DDLogError("[Realm Observation] Deleted sync settings")
                }
            }
        }

        navigationItem.hideBackButtonText()

        tableView.register(cellView: UploadTableViewCell.self)
        tableView.register(cellView: ErrorUploadTableViewCell.self)

        retryButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonRetry
        cancelButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonCancel

        setUpObserver()

        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            Task { @MainActor in
                self?.reloadCollectionView()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.uploadQueue.displayName, "Main"])
    }

    deinit {
        observedFilesNotificationToken?.invalidate()
        wifiOnlyNotificationToken?.invalidate()
    }

    func setUpObserver() {
        guard let currentDirectory, !currentDirectory.isInvalidated else {
            return
        }

        observedFilesNotificationToken?.invalidate()

        let observedFiles = AnyRealmCollection(uploadDataSource.getUploadingFiles(withParent: currentDirectory.id,
                                                                                  userId: accountManager.currentUserId,
                                                                                  driveId: currentDirectory.driveId))
        observedFilesNotificationToken = observedFiles.observe(keyPaths: UploadFile.observedProperties, on: .main) { [weak self] change in
            guard let self else {
                return
            }

            let newResults: AnyRealmCollection<UploadFile>?
            switch change {
            case .initial(let results):
                newResults = results
            case .update(let results, _, _, _):
                newResults = results
            case .error(let error):
                newResults = nil
                DDLogError("Realm observer error: \(error)")
            }

            guard let newResults else {
                reloadCollectionView(with: [])
                return
            }

            let wrappedFrozenFiles = newResults.enumerated().map { index, file in
                let frozenFile = file.freeze()
                return UploadFileDisplayed(isFirstInList: index == 0,
                                           isLastInList: index == newResults.count - 1,
                                           content: frozenFile)
            }

            reloadCollectionView(with: wrappedFrozenFiles)
        }
    }

    @MainActor func reloadCollectionView(with frozenFiles: [UploadFileDisplayed]? = nil) {
        let newSections: [ArraySection<SectionModel, UploadFileDisplayed>]
        if let frozenFiles {
            newSections = buildSections(files: frozenFiles)
        } else {
            newSections = buildSections(files: frozenUploadingFiles)
        }

        let changeSet = StagedChangeset(source: sections, target: newSections)

        tableView.reload(using: changeSet,
                         with: UITableView.RowAnimation.automatic,
                         interrupt: { $0.changeCount > Endpoint.itemsPerPage },
                         setData: { newValues in
                             if let frozenFiles {
                                 frozenUploadingFiles = frozenFiles
                             }
                             sections = newValues
                         })

        if let frozenFiles, frozenFiles.isEmpty {
            navigationController?.popViewController(animated: true)
        }
    }

    private func buildSections(files: [UploadFileDisplayed]) -> [ArraySection<SectionModel, UploadFileDisplayed>] {
        guard !isUploadLimited else {
            return [
                ArraySection(model: SectionModel.error, elements: [errorFile]),
                ArraySection(model: SectionModel.files, elements: files)
            ]
        }

        return [
            ArraySection(model: SectionModel.files, elements: files)
        ]
    }

    private var isUploadLimited: Bool {
        isWifiOnly && ReachabilityListener.instance.currentStatus == .cellular
    }

    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        uploadService.cancelAllOperations(withParent: currentDirectory.id,
                                          userId: accountManager.currentUserId,
                                          driveId: currentDirectory.driveId)
    }

    @IBAction func retryButtonPressed(_ sender: UIBarButtonItem) {
        uploadService.retryAllOperations(withParent: currentDirectory.id,
                                         userId: accountManager.currentUserId,
                                         driveId: currentDirectory.driveId)
    }

    static func instantiate() -> UploadQueueViewController {
        return Storyboard.files
            .instantiateViewController(withIdentifier: "UploadQueueViewController") as! UploadQueueViewController
    }
}

// MARK: - Table view data source

extension UploadQueueViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let rows = sections[safe: section] else {
            return 0
        }
        return rows.elements.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && isUploadLimited {
            let cell = tableView.dequeueReusableCell(type: ErrorUploadTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true,
                                           isLast: true)
            cell.delegate = self
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(type: UploadTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0,
                                           isLast: indexPath.row == self.tableView(
                                               tableView,
                                               numberOfRowsInSection: indexPath.section
                                           ) - 1)

            guard let frozenUploadingFiles = sections[safe: indexPath.section]?.elements,
                  let file = frozenUploadingFiles[safe: indexPath.row]?.content, !file.isInvalidated else {
                return cell
            }

            let progress: CGFloat? = (file.progress != nil) ? CGFloat(file.progress!) : nil
            cell.configureWith(frozenUploadFile: file, progress: progress, isUploadLimited: isUploadLimited)
            cell.selectionStyle = .none
            return cell
        }
    }
}

extension UploadQueueViewController: AccessParametersDelegate {
    func parameterButtonTapped() {
        navigationController?.pushViewController(PhotoSyncSettingsViewController(), animated: true)
    }
}
