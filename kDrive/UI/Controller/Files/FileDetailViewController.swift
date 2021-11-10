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

import kDriveCore
import UIKit

class FileDetailViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var commentButton: UIButton!

    var file: File!
    var driveFileManager: DriveFileManager!
    var sharedFile: SharedFile?

    private var activities = [[FileDetailActivity]]()
    private var activitiesInfo = (page: 1, hasNextPage: true, isLoading: true)
    private var comments = [Comment]()
    private var commentsInfo = (page: 1, hasNextPage: true, isLoading: true)

    private enum Tabs: Int {
        case informations
        case activity
        case comments
    }

    private enum FileInformationRow {
        case users
        case share
        case categories
        case owner
        case creation
        case added
        case location
        case size
        case sizeAll

        /// Build an array of row based on given file available information.
        /// - Parameters:
        ///   - file: File for which to build the array
        ///   - sharedFile: Shared file related to `file`
        /// - Returns: Array of row
        static func getRows(for file: File, sharedFile: SharedFile?, categoryRights: CategoryRights) -> [FileInformationRow] {
            var rows = [FileInformationRow]()
            if sharedFile != nil || !file.users.isEmpty {
                rows.append(.users)
            }
            if file.rights?.share ?? false {
                rows.append(.share)
            }
            if categoryRights.canReadCategoryOnFile {
                rows.append(.categories)
            }
            rows.append(.owner)
            if file.fileCreatedAtDate != nil {
                rows.append(.creation)
            }
            if file.createdAtDate != nil {
                rows.append(.added)
            }
            if sharedFile != nil || !file.path.isEmpty {
                rows.append(.location)
            }
            if file.size != 0 {
                rows.append(.size)
            }
            if file.sizeWithVersion != 0 {
                rows.append(.sizeAll)
            }
            return rows
        }
    }

    private var initialLoading = true
    private var currentTab = Tabs.informations
    private var fileInformationRows: [FileInformationRow] = []
    private var oldSections = 2

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if (tableView != nil && tableView.contentOffset.y > 0) || UIDevice.current.orientation.isLandscape || !file.hasThumbnail {
            return .default
        } else {
            return .lightContent
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.tintColor = tableView.contentOffset.y == 0 && UIDevice.current.orientation.isPortrait && file.hasThumbnail ? .white : nil
        let navigationBarAppearanceStandard = UINavigationBarAppearance()
        navigationBarAppearanceStandard.configureWithTransparentBackground()
        navigationBarAppearanceStandard.backgroundColor = KDriveAsset.backgroundColor.color
        navigationItem.standardAppearance = navigationBarAppearanceStandard
        navigationItem.compactAppearance = navigationBarAppearanceStandard

        let navigationBarAppearanceLarge = UINavigationBarAppearance()
        navigationBarAppearanceLarge.configureWithTransparentBackground()
        navigationBarAppearanceLarge.backgroundColor = .clear
        navigationItem.scrollEdgeAppearance = navigationBarAppearanceLarge

        // Reload file information
        if !initialLoading {
            loadFileInformation()
        }
        initialLoading = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.tintColor = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        commentButton.isHidden = currentTab != .comments
        tableView.contentInset.bottom = currentTab == .comments ? 120 : 0

        tableView.delegate = self
        tableView.dataSource = self

        title = ""
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        tableView.scrollIndicatorInsets = UIEdgeInsets(top: -90, left: 0, bottom: 0, right: 0)

        tableView.register(cellView: FileDetailHeaderTableViewCell.self)
        tableView.register(cellView: FileDetailHeaderAltTableViewCell.self)
        tableView.register(cellView: FileDetailCommentTableViewCell.self)
        tableView.register(cellView: FileDetailActivityTableViewCell.self)
        tableView.register(cellView: FileDetailActivitySeparatorTableViewCell.self)

        tableView.register(cellView: FileInformationUsersTableViewCell.self)
        tableView.register(cellView: ShareLinkTableViewCell.self)
        tableView.register(cellView: FileInformationOwnerTableViewCell.self)
        tableView.register(cellView: FileInformationCreationTableViewCell.self)
        tableView.register(cellView: FileInformationLocationTableViewCell.self)
        tableView.register(cellView: ManageCategoriesTableViewCell.self)
        tableView.register(cellView: FileInformationSizeTableViewCell.self)
        tableView.register(cellView: EmptyTableViewCell.self)
        tableView.register(cellView: InfoTableViewCell.self)

        tableView.separatorColor = .clear

        guard file != nil else { return }

        driveFileManager = AccountManager.instance.getDriveFileManager(for: file.driveId, userId: AccountManager.instance.currentUserId)

        // Set initial rows
        fileInformationRows = FileInformationRow.getRows(for: file, sharedFile: sharedFile, categoryRights: driveFileManager.drive.categoryRights)

        // Load file informations
        loadFileInformation()

        // Observe file changes
        driveFileManager.observeFileUpdated(self, fileId: file.id) { newFile in
            DispatchQueue.main.async { [weak self] in
                self?.file = newFile
                self?.reloadTableView()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.contentInset.bottom = tableView.safeAreaInsets.bottom
    }

    private func loadFileInformation() {
        let group = DispatchGroup()
        group.enter()
        driveFileManager.getFile(id: file.id, withExtras: true) { file, _, _ in
            if let file = file {
                self.file = file
            }
            group.leave()
        }
        group.enter()
        driveFileManager.apiFetcher.getShareListFor(file: file) { response, _ in
            self.sharedFile = response?.data
            group.leave()
        }
        group.notify(queue: .main) {
            guard self.file != nil else { return }
            self.fileInformationRows = FileInformationRow.getRows(for: self.file, sharedFile: self.sharedFile, categoryRights: self.driveFileManager.drive.categoryRights)
            self.reloadTableView()
        }
    }

    private func reloadTableView(animation: UITableView.RowAnimation = .none) {
        let newSections = numberOfSections(in: tableView)
        let sectionsInserted = newSections - oldSections
        let sectionsDeleted = oldSections - newSections
        let sectionsReloaded = min(oldSections, newSections)
        tableView.beginUpdates()
        if sectionsInserted > 0 {
            tableView.insertSections(IndexSet(oldSections..<newSections), with: animation)
        }
        if sectionsDeleted > 0 {
            tableView.deleteSections(IndexSet(newSections..<oldSections), with: animation)
        }
        tableView.reloadSections(IndexSet(1..<sectionsReloaded), with: animation)
        tableView.endUpdates()
        oldSections = newSections
    }

    private func fetchNextActivities() {
        activitiesInfo.isLoading = true
        driveFileManager.apiFetcher.getFileDetailActivity(file: file, page: activitiesInfo.page) { response, _ in
            if let data = response?.data {
                self.orderActivities(data: data)
                self.activitiesInfo.page += 1
                self.activitiesInfo.hasNextPage = data.count == DriveApiFetcher.itemPerPage
            }
            self.activitiesInfo.isLoading = false
        }
    }

    func fetchNextComments() {
        commentsInfo.isLoading = true
        driveFileManager.apiFetcher.getFileDetailComment(file: file, page: commentsInfo.page) { response, _ in
            if let data = response?.data {
                for comment in data {
                    self.comments.append(comment)
                    if let responses = comment.responses {
                        for response in responses {
                            response.isResponse = true
                            self.comments.append(response)
                        }
                    }
                }

                self.commentsInfo.page += 1
                self.commentsInfo.hasNextPage = data.count == DriveApiFetcher.itemPerPage
                if self.currentTab == .comments {
                    self.reloadTableView()
                }
            }
            self.commentsInfo.isLoading = false
        }
    }

    func orderActivities(data: [FileDetailActivity]) {
        guard !data.isEmpty else {
            tableView.reloadData()
            return
        }

        var currentDate: String
        var lastDate: String
        var notEmpty = true

        var index = activities.count - 1
        if activities.isEmpty {
            notEmpty = false
            index = 0
            activities.append([FileDetailActivity]())
            activities[index].append(data[0])
            lastDate = Constants.formatDate(Date(timeIntervalSince1970: TimeInterval()), style: .date)
        } else {
            lastDate = Constants.formatDate(Date(timeIntervalSince1970: TimeInterval(activities[index][0].createdAt)), style: .date)
        }

        for (i, activity) in data.enumerated() {
            if i != 0 || notEmpty {
                currentDate = Constants.formatDate(Date(timeIntervalSince1970: TimeInterval(activity.createdAt)), style: .date)
                if currentDate == lastDate {
                    activities[index].append(activity)
                } else {
                    index += 1
                    activities.append([FileDetailActivity]())
                    activities[index].append(activity)
                    lastDate = currentDate
                }
            }
        }
        if currentTab == .activity {
            reloadTableView()
        }
    }

    @IBAction func addComment(_ sender: UIButton) {
        let messageAlert = AlertFieldViewController(title: KDriveStrings.Localizable.buttonAddComment, placeholder: KDriveStrings.Localizable.fileDetailsCommentsFieldName, action: KDriveStrings.Localizable.buttonSend, loading: true) { comment in
            let group = DispatchGroup()
            var newComment: Comment?
            group.enter()
            self.driveFileManager.apiFetcher.addCommentTo(file: self.file, comment: comment) { response, _ in
                if let data = response?.data {
                    newComment = data
                }
                group.leave()
            }
            _ = group.wait(timeout: .now() + Constants.timeout)
            DispatchQueue.main.async {
                if let comment = newComment {
                    self.comments.insert(comment, at: 0)
                    self.tableView.reloadSections([1], with: .automatic)
                } else {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorAddComment)
                }
            }
        }
        present(messageAlert, animated: true)
    }

    func computeSizeForPopover(labels: [String]) -> CGSize {
        var height: CGFloat = 0
        var width: CGFloat = 0

        for label in labels {
            let cellSize = sizeForLabel(text: label)
            if cellSize.width > width {
                width = cellSize.width
            }
            height += cellSize.height
        }
        return CGSize(width: width + 20, height: height + 16)
    }

    private func sizeForLabel(text: String) -> CGSize {
        let testSizeLabel = UILabel()
        testSizeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        testSizeLabel.numberOfLines = 1
        testSizeLabel.text = text
        testSizeLabel.sizeToFit()

        let width = testSizeLabel.bounds.width
        let height = testSizeLabel.bounds.height
        return CGSize(width: width, height: height)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toShareLinkSettingsSegue" {
            let nextVC = segue.destination as! ShareLinkSettingsViewController
            nextVC.driveFileManager = driveFileManager
            nextVC.shareFile = sharedFile
            nextVC.file = file
        }
    }

    class func instantiate() -> FileDetailViewController {
        return Storyboard.files.instantiateViewController(withIdentifier: "FileDetailViewController") as! FileDetailViewController
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
        coder.encode(file.id, forKey: "FileId")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        let fileId = coder.decodeInteger(forKey: "FileId")
        sharedFile = coder.decodeObject(forKey: "SharedFile") as? SharedFile

        guard let driveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
        file = driveFileManager.getCachedFile(id: fileId)
        guard file != nil else {
            // If file doesn't exist anymore, pop view controller
            navigationController?.popViewController(animated: true)
            return
        }
        driveFileManager.apiFetcher.getShareListFor(file: file) { response, _ in
            self.sharedFile = response?.data
            self.fileInformationRows = FileInformationRow.getRows(for: self.file, sharedFile: self.sharedFile, categoryRights: self.driveFileManager.drive.categoryRights)
            if self.currentTab == .informations {
                DispatchQueue.main.async {
                    self.reloadTableView()
                }
            }
        }
    }
}

extension FileDetailViewController: UITableViewDelegate, UITableViewDataSource {
    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        if currentTab == .activity {
            return activities.count + 1
        }
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        switch currentTab {
        case .informations:
            return fileInformationRows.count
        case .activity:
            return activities[section - 1].count + 1
        case .comments:
            if !comments.isEmpty {
                return comments.count
            } else {
                return 1
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if !file.hasThumbnail {
                let cell = tableView.dequeueReusableCell(type: FileDetailHeaderAltTableViewCell.self, for: indexPath)
                cell.delegate = self
                cell.configureWith(file: file)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(type: FileDetailHeaderTableViewCell.self, for: indexPath)
                cell.delegate = self
                cell.configureWith(file: file)
                return cell
            }
        } else {
            switch currentTab {
            case .informations:
                switch fileInformationRows[indexPath.row] {
                case .users:
                    let cell = tableView.dequeueReusableCell(type: FileInformationUsersTableViewCell.self, for: indexPath)
                    cell.sharedFile = sharedFile
                    let userIds = file.users.isEmpty ? [file.createdBy] : Array(file.users)
                    cell.fallbackUsers = userIds.compactMap { DriveInfosManager.instance.getUser(id: $0) }
                    cell.shareButton.isHidden = !(file.rights?.share ?? false)
                    cell.delegate = self
                    cell.collectionView.reloadData()
                    return cell
                case .share:
                    let cell = tableView.dequeueReusableCell(type: ShareLinkTableViewCell.self, for: indexPath)
                    cell.delegate = self
                    cell.configureWith(sharedFile: sharedFile, file: file, insets: false)
                    return cell
                case .categories:
                    let cell = tableView.dequeueReusableCell(type: ManageCategoriesTableViewCell.self, for: indexPath)
                    cell.selectionStyle = driveFileManager.drive.categoryRights.canPutCategoryOnFile ? .default : .none
                    cell.initWithoutInsets()
                    let categories = driveFileManager.drive.categories.filter(NSPredicate(format: "id IN %@", file.categories.map(\.id)))
                    cell.configure(with: Array(categories))
                    return cell
                case .owner:
                    let cell = tableView.dequeueReusableCell(type: FileInformationOwnerTableViewCell.self, for: indexPath)
                    cell.configureWith(file: file)
                    return cell
                case .creation:
                    let cell = tableView.dequeueReusableCell(type: FileInformationCreationTableViewCell.self, for: indexPath)
                    cell.titleLabel.text = KDriveStrings.Localizable.fileDetailsInfosCreationDateTitle
                    if let creationDate = file.fileCreatedAtDate {
                        cell.creationLabel.text = Constants.formatDate(creationDate)
                    } else {
                        cell.creationLabel.text = nil
                    }
                    return cell
                case .added:
                    let cell = tableView.dequeueReusableCell(type: FileInformationCreationTableViewCell.self, for: indexPath)
                    cell.titleLabel.text = KDriveStrings.Localizable.fileDetailsInfosAddedDateTitle
                    if let creationDate = file.createdAtDate {
                        cell.creationLabel.text = Constants.formatDate(creationDate)
                    } else {
                        cell.creationLabel.text = nil
                    }
                    return cell
                case .location:
                    let cell = tableView.dequeueReusableCell(type: FileInformationLocationTableViewCell.self, for: indexPath)
                    if let drive = driveFileManager?.drive, let color = UIColor(hex: drive.preferences.color) {
                        cell.locationImage.tintColor = color
                    }
                    cell.locationLabel.text = sharedFile?.path ?? file.path
                    cell.delegate = self
                    return cell
                case .sizeAll:
                    let cell = tableView.dequeueReusableCell(type: FileInformationSizeTableViewCell.self, for: indexPath)
                    cell.titleLabel.text = KDriveStrings.Localizable.fileDetailsInfosTotalSizeTitle
                    cell.sizeLabel.text = file.getFileSize(withVersion: true)
                    return cell
                case .size:
                    let cell = tableView.dequeueReusableCell(type: FileInformationSizeTableViewCell.self, for: indexPath)
                    cell.titleLabel.text = KDriveStrings.Localizable.fileDetailsInfosOriginalSize
                    cell.sizeLabel.text = file.getFileSize()
                    return cell
                }
            case .activity:
                if indexPath.row == 0 {
                    let cell = tableView.dequeueReusableCell(type: FileDetailActivitySeparatorTableViewCell.self, for: indexPath)
                    if indexPath.section == 1 {
                        cell.topSeparatorHeight.constant = 0
                    }
                    cell.dateLabel.text = Constants.formatTimestamp(TimeInterval(activities[indexPath.section - 1][0].createdAt), style: .date, relative: true)
                    return cell
                }
                let cell = tableView.dequeueReusableCell(type: FileDetailActivityTableViewCell.self, for: indexPath)
                cell.configureWith(activity: activities[indexPath.section - 1][indexPath.row - 1], file: file)
                return cell
            case .comments:
                if file.isOfficeFile {
                    let cell = tableView.dequeueReusableCell(type: InfoTableViewCell.self, for: indexPath)
                    cell.actionHandler = { [weak self] _ in
                        guard let self = self else { return }
                        let viewController = OnlyOfficeViewController.instantiate(driveFileManager: self.driveFileManager, file: self.file, previewParent: nil)
                        self.present(viewController, animated: true)
                    }
                    return cell
                } else if !comments.isEmpty {
                    let cell = tableView.dequeueReusableCell(type: FileDetailCommentTableViewCell.self, for: indexPath)
                    cell.commentDelegate = self
                    cell.configureWith(comment: comments[indexPath.row], index: indexPath.row, response: comments[indexPath.row].isResponse)
                    return cell
                } else {
                    let cell = tableView.dequeueReusableCell(type: EmptyTableViewCell.self, for: indexPath)
                    cell.configureCell(with: .noComments)
                    return cell
                }
            }
        }
    }

    // MARK: - Table view delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let canBecomeLink = file?.rights?.canBecomeLink ?? false
        if currentTab == .informations && fileInformationRows[indexPath.row] == .share && (file.visibility != .isCollaborativeFolder) && (canBecomeLink || file.shareLink != nil) {
            let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController()
            rightsSelectionViewController.modalPresentationStyle = .fullScreen
            if let rightsSelectionVC = rightsSelectionViewController.viewControllers.first as? RightsSelectionViewController {
                rightsSelectionVC.driveFileManager = driveFileManager
                rightsSelectionVC.isFolder = file.isDirectory
                if let sharedFile = sharedFile, sharedFile.link != nil {
                    rightsSelectionVC.selectedRight = Right.shareLinkRights[1].key
                } else {
                    rightsSelectionVC.selectedRight = Right.shareLinkRights[0].key
                }
                rightsSelectionVC.rightSelectionType = .shareLinkSettings
                rightsSelectionVC.delegate = self
            }
            present(rightsSelectionViewController, animated: true)
        }
        if currentTab == .informations && fileInformationRows[indexPath.row] == .categories && driveFileManager.drive.categoryRights.canPutCategoryOnFile {
            let manageCategoriesViewController = ManageCategoriesViewController.instantiate(file: file, driveFileManager: driveFileManager)
            navigationController?.pushViewController(manageCategoriesViewController, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard currentTab == .comments && !comments.isEmpty else {
            return nil
        }

        let deleteAction = UIContextualAction(style: .destructive, title: nil) { _, _, completionHandler in
            let deleteAlert = AlertTextViewController(title: KDriveStrings.Localizable.buttonDelete, message: KDriveStrings.Localizable.modalCommentDeleteDescription, action: KDriveStrings.Localizable.buttonDelete, destructive: true, loading: true) {
                let group = DispatchGroup()
                var success = false
                group.enter()
                self.driveFileManager.apiFetcher.deleteComment(file: self.file, comment: self.comments[indexPath.row]) { response, _ in
                    if let data = response?.data {
                        success = data
                    }
                    group.leave()
                }
                _ = group.wait(timeout: .now() + Constants.timeout)
                DispatchQueue.main.async {
                    if success {
                        self.comments.remove(at: indexPath.row)
                        if !self.comments.isEmpty {
                            self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        } else {
                            self.tableView.reloadSections(IndexSet([1]), with: .automatic)
                        }
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorDelete)
                    }
                    completionHandler(success)
                }
            } cancelHandler: {
                completionHandler(false)
            }
            self.present(deleteAlert, animated: true)
        }

        let editAction = UIContextualAction(style: .normal, title: nil) { _, _, completionHandler in
            let editAlert = AlertFieldViewController(title: KDriveStrings.Localizable.modalCommentAddTitle, placeholder: KDriveStrings.Localizable.fileDetailsCommentsFieldName, text: self.comments[indexPath.row].body, action: KDriveStrings.Localizable.buttonSave, loading: true) { comment in
                let group = DispatchGroup()
                var success = false
                group.enter()
                self.driveFileManager.apiFetcher.editComment(file: self.file, text: comment, comment: self.comments[indexPath.row]) { response, _ in
                    if let data = response?.data {
                        success = data
                    }
                    group.leave()
                }
                _ = group.wait(timeout: .now() + Constants.timeout)
                DispatchQueue.main.async {
                    if success {
                        self.comments[indexPath.row].body = comment
                        self.tableView.reloadRows(at: [indexPath], with: .automatic)
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorModification)
                    }
                    completionHandler(success)
                }
            } cancelHandler: {
                completionHandler(false)
            }
            self.present(editAlert, animated: true)
        }

        let answerAction = UIContextualAction(style: .normal, title: nil) { _, _, completionHandler in
            let answerAlert = AlertFieldViewController(title: KDriveStrings.Localizable.buttonAddComment, placeholder: KDriveStrings.Localizable.fileDetailsCommentsFieldName, action: KDriveStrings.Localizable.buttonSend, loading: true) { comment in
                self.driveFileManager.apiFetcher.answerComment(file: self.file, text: comment, comment: self.comments[indexPath.row]) { response, _ in
                    if let data = response?.data {
                        data.isResponse = true
                        self.comments.insert(data, at: indexPath.row + 1)
                        self.tableView.insertRows(at: [IndexPath(row: indexPath.row + 1, section: indexPath.section)], with: .automatic)
                        completionHandler(true)
                    } else {
                        completionHandler(false)
                    }
                }
            } cancelHandler: {
                completionHandler(false)
            }
            self.present(answerAlert, animated: true)
        }

        deleteAction.image = KDriveAsset.delete.image
        deleteAction.accessibilityLabel = KDriveStrings.Localizable.buttonDelete
        editAction.image = KDriveAsset.edit.image
        editAction.accessibilityLabel = KDriveStrings.Localizable.buttonEdit
        answerAction.image = KDriveAsset.reply.image
        answerAction.accessibilityLabel = KDriveStrings.Localizable.buttonSend

        var actions: [UIContextualAction] = [deleteAction, editAction, answerAction]
        if comments[indexPath.row].isResponse {
            actions.removeAll {
                $0 == answerAction
            }
        }
        if comments[indexPath.row].user.id != AccountManager.instance.currentUserId {
            actions.removeAll {
                $0 == deleteAction || $0 == editAction
            }
        }
        let configuration = UISwipeActionsConfiguration(actions: actions)
        return configuration
    }
}

// MARK: - Scroll view delegate

extension FileDetailViewController {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        setNeedsStatusBarAppearanceUpdate()
        if UIDevice.current.orientation.isPortrait {
            if scrollView.contentOffset.y > 0 {
                title = file.name
                navigationController?.navigationBar.tintColor = nil
            } else {
                title = ""
                navigationController?.navigationBar.tintColor = file.hasThumbnail ? .white : nil
            }
        } else {
            title = scrollView.contentOffset.y > 200 ? file.name : ""
            navigationController?.navigationBar.tintColor = nil
        }

        // Infinite scroll
        let scrollPosition = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height - tableView.frame.size.height - 90
        if scrollPosition >= contentHeight {
            switch currentTab {
            case .informations:
                break
            case .activity:
                if activitiesInfo.hasNextPage && !activitiesInfo.isLoading {
                    fetchNextActivities()
                }
            case .comments:
                if commentsInfo.hasNextPage && !commentsInfo.isLoading {
                    fetchNextComments()
                }
            }
        }
    }
}

// MARK: - File detail delegate

extension FileDetailViewController: FileDetailDelegate {
    func didUpdateSegmentedControl(value: Int) {
        oldSections = tableView.numberOfSections
        currentTab = Tabs(rawValue: value) ?? .informations
        switch currentTab {
        case .informations:
            break
        case .activity:
            // Fetch first page
            if activitiesInfo.page == 1 {
                fetchNextActivities()
            }
        case .comments:
            // Fetch first page
            if commentsInfo.page == 1 {
                fetchNextComments()
            }
        }
        UIView.transition(with: tableView,
                          duration: 0.35,
                          options: .transitionCrossDissolve) {
            self.reloadTableView()
            if self.currentTab == .comments {
                self.commentButton.isHidden = self.file.isOfficeFile
            } else {
                self.commentButton.isHidden = true
            }
            self.tableView.contentInset.bottom = self.currentTab == .comments ? 120 : self.tableView.safeAreaInsets.bottom
        }
    }
}

// MARK: - File users delegate

extension FileDetailViewController: FileUsersDelegate {
    func shareButtonTapped() {
        let shareVC = ShareAndRightsViewController.instantiate(driveFileManager: driveFileManager, file: file)
        navigationController?.pushViewController(shareVC, animated: true)
    }
}

// MARK: - File location delegate

extension FileDetailViewController: FileLocationDelegate {
    func locationButtonTapped() {
        let filePresenter = FilePresenter(viewController: self, floatingPanelViewController: nil)
        if let driveFileManager = driveFileManager {
            filePresenter.presentParent(of: file, driveFileManager: driveFileManager)
        }
    }
}

// MARK: - File comment delegate

extension FileDetailViewController: FileCommentDelegate {
    func didLikeComment(comment: Comment, index: Int) {
        driveFileManager.apiFetcher.likeComment(file: file, liked: comment.liked, comment: comment) { _, _ in
            self.comments[index].likesCount = !self.comments[index].liked ? self.comments[index].likesCount + 1 : self.comments[index].likesCount - 1
            self.comments[index].liked = !self.comments[index].liked
            self.tableView.reloadRows(at: [IndexPath(row: index, section: 1)], with: .automatic)
        }
    }

    func showLikesPopover(comment: Comment, index: Int) {
        if let likes = comment.likes {
            let cell = tableView.cellForRow(at: IndexPath(row: index, section: 1)) as! FileDetailCommentTableViewCell

            let popover = FileDetailCommentPopover.instantiate()

            let labels = likes.map(\.displayName)
            popover.users = labels

            popover.modalPresentationStyle = .popover
            popover.popoverPresentationController?.delegate = self
            popover.popoverPresentationController?.sourceView = cell.likeImage
            popover.popoverPresentationController?.sourceRect = cell.likeImage.bounds
            popover.popoverPresentationController?.permittedArrowDirections = .any
            popover.popoverPresentationController?.popoverBackgroundViewClass = PopoverBackground.self

            popover.preferredContentSize = computeSizeForPopover(labels: labels)
            present(popover, animated: true)
        }
    }
}

// MARK: - Share link table view cell delegate

extension FileDetailViewController: ShareLinkTableViewCellDelegate {
    func shareLinkSharedButtonPressed(link: String, sender: UIView) {
        let items = [URL(string: link)!]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        ac.popoverPresentationController?.sourceView = sender
        present(ac, animated: true)
    }

    func shareLinkRightsButtonPressed() {
        guard let sharedLink = sharedFile?.link else {
            return
        }
        let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController()
        rightsSelectionViewController.modalPresentationStyle = .fullScreen
        if let rightsSelectionVC = rightsSelectionViewController.viewControllers.first as? RightsSelectionViewController {
            rightsSelectionVC.driveFileManager = driveFileManager
            rightsSelectionVC.isFolder = file.isDirectory
            rightsSelectionVC.delegate = self
            rightsSelectionVC.rightSelectionType = .officeOnly
            rightsSelectionVC.selectedRight = sharedLink.canEdit ? "write" : "read"
        }
        present(rightsSelectionViewController, animated: true)
    }

    func shareLinkSettingsButtonPressed() {
        performSegue(withIdentifier: "toShareLinkSettingsSegue", sender: nil)
    }
}

// MARK: - Rights selection delegate

extension FileDetailViewController: RightsSelectionDelegate {
    func didUpdateRightValue(newValue value: String) {
        driveFileManager.updateShareLink(for: file, with: sharedFile, and: value) { _, shareLink, _ in
            if let link = shareLink {
                self.sharedFile?.link = link
            } else {
                self.sharedFile?.link = nil
            }
            self.tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .automatic)
        }
    }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension FileDetailViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
