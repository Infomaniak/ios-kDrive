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
    @IBOutlet var tableView: UITableView!
    @IBOutlet var retryButton: UIBarButtonItem!
    @IBOutlet var cancelButton: UIBarButtonItem!

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var uploadQueue: UploadQueue

    var currentDirectory: File!
    private var liveUploadingFiles = [UploadFileDisplayed]()
    private var notificationToken: NotificationToken?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hideBackButtonText()

        tableView.register(cellView: UploadTableViewCell.self)

        retryButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonRetry
        cancelButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonCancel

        setUpObserver()

        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            Task { @MainActor in
                self?.tableView.reloadData()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.uploadQueue.displayName, "Main"])
    }

    deinit {
        notificationToken?.invalidate()
    }

    func setUpObserver() {
        guard let currentDirectory, !currentDirectory.isInvalidated else {
            return
        }

        notificationToken?.invalidate()

        let observedFiles = AnyRealmCollection(uploadQueue.getUploadingFiles(withParent: currentDirectory.id,
                                                                             userId: accountManager.currentUserId,
                                                                             driveId: currentDirectory.driveId))
        notificationToken = observedFiles.observe(keyPaths: UploadFile.observedProperties, on: .main) { [weak self] change in
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
                reloadCollectionViewWith([])
                return
            }

            let wrappedFiles = newResults.enumerated().map { index, item in
                UploadFileDisplayed(isFirstInList: index == 0,
                                    isLastInList: index == newResults.count - 1,
                                    content: item)
            }

            reloadCollectionViewWith(wrappedFiles)
        }
    }

    func reloadCollectionViewWith(_ files: [UploadFileDisplayed]) {
        let changeSet = StagedChangeset(source: liveUploadingFiles, target: files)
        tableView.reload(using: changeSet,
                         with: UITableView.RowAnimation.automatic,
                         interrupt: { $0.changeCount > Endpoint.itemsPerPage },
                         setData: { self.liveUploadingFiles = $0 })

        if files.isEmpty {
            navigationController?.popViewController(animated: true)
        }
    }

    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        uploadQueue.cancelAllOperations(withParent: currentDirectory.id,
                                        userId: accountManager.currentUserId,
                                        driveId: currentDirectory.driveId)
    }

    @IBAction func retryButtonPressed(_ sender: UIBarButtonItem) {
        uploadQueue.retryAllOperations(withParent: currentDirectory.id,
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
        return liveUploadingFiles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: UploadTableViewCell.self, for: indexPath)
        let fileWrapper = liveUploadingFiles[indexPath.row]
        let file = fileWrapper.content

        cell.initWithPositionAndShadow(isFirst: fileWrapper.isFirstInList,
                                       isLast: fileWrapper.isLastInList)

        if !file.isInvalidated {
            let progress: CGFloat? = (file.progress != nil) ? CGFloat(file.progress!) : nil
            cell.configureWith(uploadFile: file, progress: progress)
        }

        cell.selectionStyle = .none
        return cell
    }
}
