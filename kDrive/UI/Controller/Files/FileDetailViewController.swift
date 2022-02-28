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
import kDriveResources
import UIKit

class FileDetailViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var commentButton: UIButton!

    var file: File!
    var driveFileManager: DriveFileManager!
    var fileAccess: FileAccess?

    private var activities = [[FileActivity]]()
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
        ///   - fileAccess: Shared file related to `file`
        /// - Returns: Array of row
        static func getRows(for file: File, fileAccess: FileAccess?, categoryRights: CategoryRights) -> [FileInformationRow] {
            var rows = [FileInformationRow]()
            if fileAccess != nil || !file.users.isEmpty {
                rows.append(.users)
            }
            if file.capabilities.canShare {
                rows.append(.share)
            }
            if categoryRights.canReadCategoryOnFile {
                rows.append(.categories)
            }
            rows.append(.owner)
            if file.createdAt != nil {
                rows.append(.creation)
            }
            rows.append(.added)
            if file.path?.isEmpty == false {
                rows.append(.location)
            }
            if file.size != nil {
                rows.append(.size)
            }
            if file.version != nil {
                rows.append(.sizeAll)
            }
            return rows
        }
    }

    private var initialLoading = true
    private var currentTab = Tabs.informations
    private var fileInformationRows: [FileInformationRow] = []
    private var oldSections = 2

    private var canManageCategories: Bool {
        return driveFileManager.drive.categoryRights.canPutCategoryOnFile && !file.isDisabled
    }

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
        navigationBarAppearanceStandard.backgroundColor = KDriveResourcesAsset.backgroundColor.color
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: ["FileDetail"])
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

        navigationItem.backButtonTitle = file.name
        navigationItem.hideBackButtonText()

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

        // Set initial rows
        fileInformationRows = FileInformationRow.getRows(for: file, fileAccess: fileAccess, categoryRights: driveFileManager.drive.categoryRights)

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
        Task {
            do {
                self.file = try await driveFileManager.file(id: file.id, forceRefresh: true)
                self.fileAccess = try? await driveFileManager.apiFetcher.access(for: file)
                guard self.file != nil else { return }
                self.fileInformationRows = FileInformationRow.getRows(for: self.file, fileAccess: self.fileAccess, categoryRights: self.driveFileManager.drive.categoryRights)
                self.reloadTableView()
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
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
        Task {
            do {
                let pagedActivities = try await driveFileManager.apiFetcher.fileActivities(file: file, page: activitiesInfo.page)
                self.orderActivities(data: pagedActivities)
                self.activitiesInfo.page += 1
                self.activitiesInfo.hasNextPage = pagedActivities.count == Endpoint.itemsPerPage
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
            self.activitiesInfo.isLoading = false
        }
    }

    func fetchNextComments() {
        commentsInfo.isLoading = true
        Task {
            do {
                let pagedPictures = try await driveFileManager.apiFetcher.comments(file: file, page: commentsInfo.page)
                for comment in pagedPictures {
                    self.comments.append(comment)
                    if let responses = comment.responses {
                        for response in responses {
                            response.isResponse = true
                            self.comments.append(response)
                        }
                    }
                }

                self.commentsInfo.page += 1
                self.commentsInfo.hasNextPage = pagedPictures.count == Endpoint.itemsPerPage
                if self.currentTab == .comments {
                    self.reloadTableView()
                }
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
            self.commentsInfo.isLoading = false
        }
    }

    func orderActivities(data: [FileActivity]) {
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
            activities.append([FileActivity]())
            activities[index].append(data[0])
            lastDate = Constants.formatDate(Date(timeIntervalSince1970: TimeInterval()), style: .date)
        } else {
            lastDate = Constants.formatDate(activities[index][0].createdAt, style: .date)
        }

        for (i, activity) in data.enumerated() {
            if i != 0 || notEmpty {
                currentDate = Constants.formatDate(activity.createdAt, style: .date)
                if currentDate == lastDate {
                    activities[index].append(activity)
                } else {
                    index += 1
                    activities.append([FileActivity]())
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
        MatomoUtils.track(eventWithCategory: .comment, name: "add")
        let messageAlert = AlertFieldViewController(title: KDriveResourcesStrings.Localizable.buttonAddComment, placeholder: KDriveResourcesStrings.Localizable.fileDetailsCommentsFieldName, action: KDriveResourcesStrings.Localizable.buttonSend, loading: true) { body in
            do {
                let newComment = try await self.driveFileManager.apiFetcher.addComment(to: self.file, body: body)
                self.comments.insert(newComment, at: 0)
                self.tableView.reloadSections([1], with: .automatic)
            } catch {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorAddComment)
            }
        }
        present(messageAlert, animated: true)
    }

    func computeSizeForPopover(labels: [String]) -> CGSize {
        var height = 0.0
        var width = 0.0

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
            nextVC.file = file
        }
    }

    class func instantiate(driveFileManager: DriveFileManager, file: File) -> FileDetailViewController {
        let viewController = Storyboard.files.instantiateViewController(withIdentifier: "FileDetailViewController") as! FileDetailViewController
        viewController.driveFileManager = driveFileManager
        viewController.file = file
        return viewController
    }

    // MARK: - Private methods

    private func delete(at indexPath: IndexPath, actionCompletion: (Bool) -> Void) async {
        MatomoUtils.track(eventWithCategory: .comment, name: "delete")
        let comment = self.comments[indexPath.row]
        do {
            let response = try await driveFileManager.apiFetcher.deleteComment(file: file, comment: comment)
            if response {
                let commentToDelete = comments[indexPath.row]
                let rowsToDelete = (0...commentToDelete.responsesCount).map { index in
                    IndexPath(row: indexPath.row + index, section: indexPath.section)
                }
                if commentToDelete.isResponse {
                    let parentComment = comments.first { $0.id == commentToDelete.parentId }
                    parentComment?.responsesCount -= 1
                }
                comments.removeSubrange(indexPath.row...indexPath.row + commentToDelete.responsesCount)
                if !comments.isEmpty {
                    tableView.deleteRows(at: rowsToDelete, with: .automatic)
                } else {
                    tableView.reloadSections(IndexSet([1]), with: .automatic)
                }
                actionCompletion(true)
            } else {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorDelete)
                actionCompletion(false)
            }
        } catch {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorDelete)
            actionCompletion(false)
        }
    }

    private func edit(at indexPath: IndexPath, body: String, actionCompletion: (Bool) -> Void) async {
        MatomoUtils.track(eventWithCategory: .comment, name: "edit")
        let comment = self.comments[indexPath.row]
        do {
            let response = try await driveFileManager.apiFetcher.editComment(file: file, body: body, comment: comment)
            if response {
                comments[indexPath.row].body = body
                tableView.reloadRows(at: [indexPath], with: .automatic)
                actionCompletion(true)
            } else {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorModification)
                actionCompletion(false)
            }
        } catch {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorModification)
            actionCompletion(false)
        }
    }

    private func answer(at indexPath: IndexPath, reply: String, actionCompletion: (Bool) -> Void) async {
        MatomoUtils.track(eventWithCategory: .comment, name: "answer")
        let comment = self.comments[indexPath.row]
        do {
            let reply = try await driveFileManager.apiFetcher.answerComment(file: file, body: reply, comment: comment)
            reply.isResponse = true
            comments.insert(reply, at: indexPath.row + 1)
            let parentComment = comments[indexPath.row]
            if parentComment.responses != nil {
                parentComment.responses?.insert(reply, at: 0)
            } else {
                parentComment.responses = [reply]
            }
            parentComment.responsesCount += 1
            tableView.insertRows(at: [IndexPath(row: indexPath.row + 1, section: indexPath.section)], with: .automatic)
            actionCompletion(true)
        } catch {
            actionCompletion(false)
        }
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
        Task {
            self.fileAccess = try? await driveFileManager.apiFetcher.access(for: file)
            self.fileInformationRows = FileInformationRow.getRows(for: self.file, fileAccess: self.fileAccess, categoryRights: self.driveFileManager.drive.categoryRights)
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
                    if let fileAccess = fileAccess {
                        cell.fileAccessElements = fileAccess.teams + fileAccess.users
                    }
                    cell.shareButton.isHidden = !file.capabilities.canShare
                    cell.delegate = self
                    cell.collectionView.reloadData()
                    return cell
                case .share:
                    let cell = tableView.dequeueReusableCell(type: ShareLinkTableViewCell.self, for: indexPath)
                    cell.delegate = self
                    cell.configureWith(file: file, insets: false)
                    return cell
                case .categories:
                    let cell = tableView.dequeueReusableCell(type: ManageCategoriesTableViewCell.self, for: indexPath)
                    cell.canManage = canManageCategories
                    cell.initWithoutInsets()
                    cell.configure(with: driveFileManager.drive.categories(for: file))
                    return cell
                case .owner:
                    let cell = tableView.dequeueReusableCell(type: FileInformationOwnerTableViewCell.self, for: indexPath)
                    cell.configureWith(file: file)
                    return cell
                case .creation:
                    let cell = tableView.dequeueReusableCell(type: FileInformationCreationTableViewCell.self, for: indexPath)
                    cell.titleLabel.text = KDriveResourcesStrings.Localizable.fileDetailsInfosCreationDateTitle
                    if let creationDate = file.createdAt {
                        cell.creationLabel.text = Constants.formatDate(creationDate)
                    } else {
                        cell.creationLabel.text = nil
                    }
                    return cell
                case .added:
                    let cell = tableView.dequeueReusableCell(type: FileInformationCreationTableViewCell.self, for: indexPath)
                    cell.titleLabel.text = KDriveResourcesStrings.Localizable.fileDetailsInfosAddedDateTitle
                    cell.creationLabel.text = Constants.formatDate(file.addedAt)
                    return cell
                case .location:
                    let cell = tableView.dequeueReusableCell(type: FileInformationLocationTableViewCell.self, for: indexPath)
                    if let drive = driveFileManager?.drive, let color = UIColor(hex: drive.preferences.color) {
                        cell.locationImage.tintColor = color
                    }
                    cell.locationLabel.text = file.path
                    cell.delegate = self
                    return cell
                case .sizeAll:
                    let cell = tableView.dequeueReusableCell(type: FileInformationSizeTableViewCell.self, for: indexPath)
                    cell.titleLabel.text = KDriveResourcesStrings.Localizable.fileDetailsInfosTotalSizeTitle
                    cell.sizeLabel.text = file.getFileSize(withVersion: true)
                    return cell
                case .size:
                    let cell = tableView.dequeueReusableCell(type: FileInformationSizeTableViewCell.self, for: indexPath)
                    cell.titleLabel.text = KDriveResourcesStrings.Localizable.fileDetailsInfosOriginalSize
                    cell.sizeLabel.text = file.getFileSize()
                    return cell
                }
            case .activity:
                if indexPath.row == 0 {
                    let cell = tableView.dequeueReusableCell(type: FileDetailActivitySeparatorTableViewCell.self, for: indexPath)
                    if indexPath.section == 1 {
                        cell.topSeparatorHeight.constant = 0
                    }
                    cell.dateLabel.text = Constants.formatDate(activities[indexPath.section - 1][0].createdAt, style: .date, relative: true)
                    return cell
                }
                let cell = tableView.dequeueReusableCell(type: FileDetailActivityTableViewCell.self, for: indexPath)
                cell.configure(with: activities[indexPath.section - 1][indexPath.row - 1], file: file)
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
        let canBecomeLink = file?.capabilities.canBecomeSharelink ?? false
        if currentTab == .informations && fileInformationRows[indexPath.row] == .share && !file.isDropbox && (canBecomeLink || file.hasSharelink) {
            let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController(file: file, driveFileManager: driveFileManager)
            rightsSelectionViewController.modalPresentationStyle = .fullScreen
            if let rightsSelectionVC = rightsSelectionViewController.viewControllers.first as? RightsSelectionViewController {
                rightsSelectionVC.selectedRight = (file.hasSharelink ? ShareLinkPermission.public : ShareLinkPermission.restricted).rawValue
                rightsSelectionVC.rightSelectionType = .shareLinkSettings
                rightsSelectionVC.delegate = self
            }
            present(rightsSelectionViewController, animated: true)
        }
        if currentTab == .informations && fileInformationRows[indexPath.row] == .categories && canManageCategories {
            let manageCategoriesViewController = ManageCategoriesViewController.instantiate(file: file, driveFileManager: driveFileManager)
            navigationController?.pushViewController(manageCategoriesViewController, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Only the cells of the "comments" view can be slid, and this behavior concerns only the content cells, not the header
        guard currentTab == .comments && !comments.isEmpty && indexPath.section >= 1 else {
            return nil
        }

        let deleteAction = UIContextualAction(style: .destructive, title: nil) { _, _, completionHandler in
            let deleteAlert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.buttonDelete, message: KDriveResourcesStrings.Localizable.modalCommentDeleteDescription, action: KDriveResourcesStrings.Localizable.buttonDelete, destructive: true, loading: true) { [weak self] in
                await self?.delete(at: indexPath, actionCompletion: completionHandler)
            } cancelHandler: {
                completionHandler(false)
            }
            self.present(deleteAlert, animated: true)
        }

        let editAction = UIContextualAction(style: .normal, title: nil) { _, _, completionHandler in
            let editAlert = AlertFieldViewController(title: KDriveResourcesStrings.Localizable.modalCommentAddTitle, placeholder: KDriveResourcesStrings.Localizable.fileDetailsCommentsFieldName, text: self.comments[indexPath.row].body, action: KDriveResourcesStrings.Localizable.buttonSave, loading: true) { [weak self] body in
                await self?.edit(at: indexPath, body: body, actionCompletion: completionHandler)
            } cancelHandler: {
                completionHandler(false)
            }
            self.present(editAlert, animated: true)
        }

        let answerAction = UIContextualAction(style: .normal, title: nil) { _, _, completionHandler in
            let answerAlert = AlertFieldViewController(title: KDriveResourcesStrings.Localizable.buttonAddComment, placeholder: KDriveResourcesStrings.Localizable.fileDetailsCommentsFieldName, action: KDriveResourcesStrings.Localizable.buttonSend, loading: true) { [weak self] body in
                await self?.answer(at: indexPath, reply: body, actionCompletion: completionHandler)
            } cancelHandler: {
                completionHandler(false)
            }
            self.present(answerAlert, animated: true)
        }

        deleteAction.image = KDriveResourcesAsset.delete.image
        deleteAction.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonDelete
        editAction.image = KDriveResourcesAsset.edit.image
        editAction.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonEdit
        answerAction.image = KDriveResourcesAsset.reply.image
        answerAction.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonSend

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
        MatomoUtils.track(eventWithCategory: .fileInfo, name: "switchView\(["Info", "Activities", "Comments"][value])")
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
        MatomoUtils.track(eventWithCategory: .comment, name: "like")
        Task {
            do {
                let response = try await driveFileManager.apiFetcher.likeComment(file: file, liked: comment.liked, comment: comment)
                if response {
                    self.comments[index].likesCount = !self.comments[index].liked ? self.comments[index].likesCount + 1 : self.comments[index].likesCount - 1
                    self.comments[index].liked = !self.comments[index].liked
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 1)], with: .automatic)
                }
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
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

    func shareLinkSettingsButtonPressed() {
        performSegue(withIdentifier: "toShareLinkSettingsSegue", sender: nil)
    }
}

// MARK: - Rights selection delegate

extension FileDetailViewController: RightsSelectionDelegate {
    func didUpdateRightValue(newValue value: String) {
        let right = ShareLinkPermission(rawValue: value)!
        Task {
            _ = try await driveFileManager.createOrRemoveShareLink(for: file, right: right)
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
