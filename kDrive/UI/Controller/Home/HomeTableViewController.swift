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

import UIKit
import kDriveCore
import InfomaniakCore
import DifferenceKit
import CocoaLumberjackSwift

protocol HomeFileDelegate: AnyObject {
    func didSelect(index: Int, files: [File])
}

class HomeTableViewController: UITableViewController, SwitchDriveDelegate, SwitchAccountDelegate, HomeFileDelegate, TopScrollable {

    private enum HomeSection: Differentiable {
        case top
        case lastModify
        case activityOrPictures
    }
    private enum HomeTopRows {
        case offline
        case drive
        case search
        case insufficientStorage
    }
    private enum HomeLastModifyRows {
        case lastModify
    }
    private enum HomeActivityOrPicturesRows {
        case recentActivity
        case lastPictures
        case emptyActivity
        case emptyPictures
        case emptyAll
    }

    private var sections = [HomeSection]()
    private var topRows = [HomeTopRows]()
    private var lastModifyRows: [HomeLastModifyRows] = [.lastModify]
    private var activityOrPicturesRowType: HomeActivityOrPicturesRows = .recentActivity

    private var lastModifiedFiles = [File]()
    private var lastModifyIsLoading = true
    private var lastPictures = [File]()
    private var recentActivityController: RecentActivitySharedController?
    private var recentActivities: [FileActivity] {
        return recentActivityController?.recentActivities ?? []
    }
    private lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)
    private var lastPicturesInfo = (page: 1, hasNextPage: true, isLoading: true)
    private var activityOrPicturesIsLoading = true
    private var shouldLoadMore: Bool {
        if driveFileManager.drive.isProOrTeam {
            return recentActivityController?.shouldLoadMore ?? false
        } else {
            return false // lastPicturesInfo.hasNextPage && !lastPicturesInfo.isLoading -> infinite scroll is disabled for now
        }
    }

    private var filesObserver: ObservationToken?
    private var needsContentUpdate = false
    private var showInsufficientStorage = true
    private var lastUpdate = Date()
    private let updateDelay: TimeInterval = 60 // 1 minute

    private var floatingPanelViewController: DriveFloatingPanelController?

    private var footerLoader: UIView = {
        let indicator = UIActivityIndicatorView(style: .gray)
        indicator.color = KDriveAsset.loaderDarkerDefaultColor.color
        indicator.startAnimating()
        return indicator
    }()

    private var footerAllImages: UIView = {
        let button = UIButton(type: .system)
        button.setTitle(KDriveStrings.Localizable.homeSeeAllImages, for: .normal)
        button.addTarget(self, action: #selector(showAllImages), for: .touchUpInside)
        return button
    }()

    private var navbarHeight: CGFloat {
        return navigationController?.navigationBar.frame.height ?? 0
    }

    var driveFileManager: DriveFileManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never

        tableView.register(cellView: DriveSwitchTableViewCell.self)
        tableView.register(cellView: HomeFileSearchTableViewCell.self)
        tableView.register(cellView: HomeLastModifTableViewCell.self)
        tableView.register(cellView: HomeLastPicTableViewCell.self)
        tableView.register(cellView: RecentActivityTableViewCell.self)
        tableView.register(cellView: HomeOfflineTableViewCell.self)
        tableView.register(cellView: EmptyTableViewCell.self)
        tableView.register(cellView: InsufficientStorageTableViewCell.self)

        refreshControl?.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.sectionFooterHeight = 22
        tableView.contentInsetAdjustmentBehavior = .never
        if UIApplication.shared.statusBarOrientation.isPortrait {
            tableView.contentInset.top = UIConstants.homeListPaddingTop
        } else {
            tableView.contentInset.top = 0
        }
        tableView.contentInset.bottom = UIConstants.listPaddingBottom
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: navbarHeight, left: 0, bottom: 0, right: 0)

        initViewWithCurrentDrive()

        // Table view footer
        showFooter(!(driveFileManager?.drive.isProOrTeam ?? true))

        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] status in
            self.reload(sections: [.top])
            if status != .offline {
                self.reloadData()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.barTintColor = KDriveAsset.backgroundColor.color
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: KDriveAsset.titleColor.color]
        updateNavbarAppearance()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        tableView.isScrollEnabled = !activityOrPicturesIsLoading

        updateContentIfNeeded()

        reload(sections: [.top])
        updateNavbarAppearance()
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.shadowImage = nil
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.barTintColor = nil
        navigationController?.navigationBar.titleTextAttributes = nil
        navigationController?.navigationBar.alpha = 1
        navigationController?.navigationBar.isUserInteractionEnabled = true
        navigationController?.navigationBar.layoutIfNeeded()
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    @objc func forceRefresh() {
        reloadData()
    }

    @objc func rotated() {
        if UIApplication.shared.statusBarOrientation.isPortrait {
            let insetTop = navigationController?.tabBarController?.view.safeAreaInsets.bottom == 0 ? -UIConstants.homeListPaddingTop : UIConstants.homeListPaddingTop
            if tableView.contentOffset.y == 0 {
                tableView.contentOffset.y = -insetTop
            }
            tableView.contentInset.top = insetTop
        } else {
            tableView.contentInset.top = 0
        }
        tableView.scrollIndicatorInsets.top = navbarHeight
        updateNavbarAppearance()
    }

    func presentedFromTabBar() {
        // Reload data
        if !needsContentUpdate && Date().timeIntervalSince(lastUpdate) > updateDelay {
            reloadData()
        }
    }

    func updateContentIfNeeded() {
        if needsContentUpdate && view.window != nil {
            needsContentUpdate = false
            initViewWithCurrentDrive()
        }
    }

    func initViewWithCurrentDrive() {
        guard driveFileManager != nil else {
            return
        }

        // Load last modified files
        lastModifiedFiles.removeAll()
        loadLastModifiedFiles()

        // Load activity/pictures
        if driveFileManager.drive.isProOrTeam {
            recentActivityController = RecentActivitySharedController(driveFileManager: AccountManager.instance.getDriveFileManager(for: driveFileManager.drive)!, filePresenter: filePresenter)
            loadNextRecentActivities()
        } else {
            lastPicturesInfo.page = 1
            lastPicturesInfo.hasNextPage = true
            lastPictures.removeAll()
            loadNextLastPictures()
        }

        // Reload table view
        updateSectionList()
        updateTopRows()
        updateActivityOrPicturesRowType()
        observeFileUpdated()
        tableView.reloadData()
    }

    private func updateSectionList() {
        if lastModifiedFiles.isEmpty && !lastModifyIsLoading {
            sections = [.top, .activityOrPictures]
        } else {
            sections = [.top, .lastModify, .activityOrPictures]
        }
    }

    private func updateTopRows() {
        if ReachabilityListener.instance.currentStatus == .offline {
            topRows = [.offline, .drive, .search]
        } else {
            topRows = [.drive, .search]
        }

        guard driveFileManager != nil && driveFileManager.drive.size > 0 else {
            return
        }
        let storagePercentage = Double(driveFileManager.drive.usedSize) / Double(driveFileManager.drive.size) * 100
        if (storagePercentage > UIConstants.insufficientStorageMinimumPercentage) && showInsufficientStorage {
            topRows.append(.insufficientStorage)
        }
    }

    private func updateActivityOrPicturesRowType() {
        if driveFileManager.drive.isProOrTeam {
            if recentActivities.isEmpty && !activityOrPicturesIsLoading {
                activityOrPicturesRowType = .emptyActivity
            } else {
                activityOrPicturesRowType = .recentActivity
            }
        } else {
            if lastPictures.isEmpty && lastModifiedFiles.isEmpty && !lastModifyIsLoading && !activityOrPicturesIsLoading {
                activityOrPicturesRowType = .emptyAll
            } else if lastPictures.isEmpty && !activityOrPicturesIsLoading {
                activityOrPicturesRowType = .emptyPictures
            } else {
                activityOrPicturesRowType = .lastPictures
            }
        }
        if view.window != nil {
            tableView.isScrollEnabled = !activityOrPicturesIsLoading
        }
    }

    func observeFileUpdated() {
        filesObserver?.cancel()
        filesObserver = driveFileManager.observeFileUpdated(self, fileId: nil) { [unowned self] file in
            if lastModifiedFiles.contains(where: { $0.id == file.id }) || lastPictures.contains(where: { $0.id == file.id }) {
                needsContentUpdate = true
            }
        }
    }

    private func reload(sections sectionsToReload: [HomeSection]) {
        // Insert/delete sections
        let oldSections = sections
        updateSectionList()
        let changeset = StagedChangeset(source: oldSections, target: sections)
        for set in changeset {
            tableView.beginUpdates()
            tableView.deleteSections(IndexSet(set.elementDeleted.map(\.element)), with: .automatic)
            tableView.insertSections(IndexSet(set.elementInserted.map(\.element)), with: .automatic)
            tableView.endUpdates()
        }

        // Update sections content
        if sectionsToReload.contains(.top) {
            updateTopRows()
        }
        if sectionsToReload.contains(.activityOrPictures) {
            updateActivityOrPicturesRowType()
        }

        // Reload sections
        let indexSet = sectionsToReload.compactMap { sections.firstIndex(of: $0) }
        tableView.reloadSections(IndexSet(indexSet), with: .automatic)
    }

    func loadLastModifiedFiles() {
        lastUpdate = Date()
        lastModifyIsLoading = true
        driveFileManager.getLastModifiedFiles { [self] files, _ in
            if let files = files, files.map(\.id) != lastModifiedFiles.map(\.id) {
                lastModifiedFiles = files
                lastModifyIsLoading = false
                reload(sections: [.lastModify])
            }
        }
    }

    func loadNextLastPictures() {
        showFooter(true)
        lastUpdate = Date()
        lastPicturesInfo.isLoading = true
        activityOrPicturesIsLoading = lastPicturesInfo.page == 1
        driveFileManager.getLastPictures(page: lastPicturesInfo.page) { files, _ in
            if let files = files {
                self.lastPictures += files
                self.refreshControl?.endRefreshing()
                // self.showFooter(false)
                self.activityOrPicturesIsLoading = false
                self.reload(sections: [.activityOrPictures])
                self.lastPicturesInfo.page += 1
                self.lastPicturesInfo.hasNextPage = files.count == DriveApiFetcher.itemPerPage
                self.lastPicturesInfo.isLoading = false
            } else {
                self.refreshControl?.endRefreshing()
                // self.showFooter(false)
                self.activityOrPicturesIsLoading = false
                self.lastPicturesInfo.isLoading = false
            }
        }
    }

    func loadNextRecentActivities() {
        guard let recentActivityController = recentActivityController else {
            return
        }

        showFooter(true)
        lastUpdate = Date()
        activityOrPicturesIsLoading = recentActivityController.nextPage == 1
        recentActivityController.loadNextRecentActivities { error in
            self.showFooter(false)
            self.activityOrPicturesIsLoading = false
            self.refreshControl?.endRefreshing()
            if let error = error {
                DDLogError("Error while fetching recent activities: \(error)")
            } else {
                self.reload(sections: [.activityOrPictures])
            }
        }
    }

    func reloadData() {
        guard !activityOrPicturesIsLoading, driveFileManager != nil else {
            return
        }

        lastModifiedFiles.removeAll()
        loadLastModifiedFiles()
        if driveFileManager.drive.isProOrTeam {
            recentActivityController?.prepareForReload()
            loadNextRecentActivities()
        } else {
            lastPicturesInfo.page = 1
            lastPicturesInfo.hasNextPage = true
            lastPictures.removeAll()
            loadNextLastPictures()
        }
        reload(sections: [.lastModify, .activityOrPictures])

    }

    func showFooter(_ show: Bool) {
        let isProOrTeam = driveFileManager?.drive.isProOrTeam ?? true
        tableView.tableFooterView = isProOrTeam ? footerLoader : footerAllImages
        tableView.tableFooterView?.isHidden = !show
        tableView.tableFooterView?.frame.size.height = show ? 44 : 0
        let inset: CGFloat = isProOrTeam ? 76 : 68
        tableView.contentInset.bottom = show ? UIConstants.listPaddingBottom + inset : UIConstants.listPaddingBottom
    }

    @objc func showAllImages() {
        let photoListViewController = PhotoListViewController.instantiate()
        photoListViewController.driveFileManager = driveFileManager
        navigationController?.pushViewController(photoListViewController, animated: true)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sections[section] {
        case .top:
            return 0
        case .lastModify:
            return 33
        case .activityOrPictures:
            switch activityOrPicturesRowType {
            case .recentActivity, .lastPictures, .emptyPictures:
                return 33
            case .emptyActivity, .emptyAll:
                return .leastNormalMagnitude
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section] {
        case .top:
            switch topRows[indexPath.row] {
            case .offline:
                return 120
            case .drive:
                return 91
            default:
                return UITableView.automaticDimension
            }
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .top:
            return topRows.count
        case .lastModify:
            return lastModifyRows.count
        case .activityOrPictures:
            switch activityOrPicturesRowType {
            case .recentActivity:
                return activityOrPicturesIsLoading ? 3 : recentActivities.count
            default:
                return 1
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .top:
            switch topRows[indexPath.row] {
            case .offline:
                let cell = tableView.dequeueReusableCell(type: HomeOfflineTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.selectionStyle = .none
                return cell
            case .drive:
                let cell = tableView.dequeueReusableCell(type: DriveSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.configureWith(drive: driveFileManager.drive)
                return cell
            case .search:
                let cell = tableView.dequeueReusableCell(type: HomeFileSearchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                return cell
            case .insufficientStorage:
                let cell = tableView.dequeueReusableCell(type: InsufficientStorageTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.configureCell(with: driveFileManager.drive)
                cell.selectionStyle = .none
                cell.actionHandler = { [self] _ in
                    if let url = URL(string: "\(ApiRoutes.orderDrive())/\(driveFileManager.drive.id)") {
                        UIApplication.shared.open(url)
                    }
                }
                cell.closeHandler = { [self] _ in
                    topRows.remove(at: topRows.count - 1)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    showInsufficientStorage = false
                }
                return cell
            }
        case .lastModify:
            let cell = tableView.dequeueReusableCell(type: HomeLastModifTableViewCell.self, for: indexPath)
            if lastModifyIsLoading {
                cell.configureLoading()
            } else {
                cell.configureWith(files: lastModifiedFiles)
            }
            cell.delegate = self
            return cell
        case .activityOrPictures:
            switch activityOrPicturesRowType {
            case .recentActivity:
                let cell = tableView.dequeueReusableCell(type: RecentActivityTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                if activityOrPicturesIsLoading {
                    cell.configureLoading()
                } else {
                    cell.configureWith(recentActivity: recentActivities[indexPath.row])
                }
                cell.layoutIfNeeded()
                cell.collectionView.reloadData()
                cell.tableView.reloadData()
                cell.delegate = recentActivityController
                return cell
            case .lastPictures:
                let cell = tableView.dequeueReusableCell(type: HomeLastPicTableViewCell.self, for: indexPath)
                if activityOrPicturesIsLoading {
                    cell.configureLoading()
                } else {
                    cell.configureWith(files: lastPictures)
                    cell.delegate = self
                }
                return cell
            case .emptyActivity:
                let cell = tableView.dequeueReusableCell(type: EmptyTableViewCell.self, for: indexPath)
                cell.configureCell(with: .noActivities)
                return cell
            case .emptyPictures:
                let cell = tableView.dequeueReusableCell(type: EmptyTableViewCell.self, for: indexPath)
                cell.configureCell(with: .noImages)
                return cell
            case .emptyAll:
                let cell = tableView.dequeueReusableCell(type: EmptyTableViewCell.self, for: indexPath)
                cell.configureCell(with: .noActivitiesSolo)
                return cell
            }
        }
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .top:
            return nil
        case .lastModify:
            return HomeTitleView.instantiate(title: KDriveStrings.Localizable.homeLastFilesTitle)
        case .activityOrPictures:
            switch activityOrPicturesRowType {
            case .recentActivity:
                return HomeTitleView.instantiate(title: KDriveStrings.Localizable.homeLastActivities)
            case .lastPictures, .emptyPictures:
                return HomeTitleView.instantiate(title: KDriveStrings.Localizable.homeMyLastPictures)
            case .emptyActivity, .emptyAll:
                return nil
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .top:
            switch topRows[indexPath.row] {
            case .offline, .insufficientStorage:
                return
            case .drive:
                performSegue(withIdentifier: "switchDriveSegue", sender: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            case .search:
                present(SearchViewController.instantiateInNavigationController(driveFileManager: driveFileManager), animated: true)
            }
        default:
            return
        }
    }

    // MARK: - Scroll view delegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateNavbarAppearance()

        // Infinite scroll
        let scrollPosition = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height - tableView.frame.size.height
        // isDragging and isDecelerating make sure this is a user scroll
        if scrollPosition > contentHeight && (scrollView.isDragging || scrollView.isDecelerating) && shouldLoadMore {
            if driveFileManager.drive.isProOrTeam {
                loadNextRecentActivities()
            } else {
                loadNextLastPictures()
            }
        }
    }

    private func updateNavbarAppearance() {
        let scrollOffset = tableView.contentOffset.y
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }
        if UIApplication.shared.statusBarOrientation.isPortrait {
            navigationItem.title = (driveFileManager.drive.name)
            navigationBar.alpha = min(1, max(0, (scrollOffset + tableView.contentInset.top) / navbarHeight))
            navigationBar.isUserInteractionEnabled = navigationBar.alpha > 0.5
        } else {
            navigationBar.isUserInteractionEnabled = false
            navigationItem.title = ""
            navigationBar.alpha = 0
        }
        navigationBar.layoutIfNeeded()
    }

    // MARK: - Switch drive delegate

    func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
        driveFileManager = newDriveFileManager
        lastModifiedFiles.removeAll()
        lastPictures.removeAll()
        recentActivityController?.invalidate()
        recentActivityController = nil
        tableView.reloadData()
        needsContentUpdate = true
        updateContentIfNeeded()
    }

    // MARK: - Switch account delegate

    func didSwitchCurrentAccount(_ newAccount: Account) {

    }

    func didUpdateCurrentAccountInformations(_ currentAccount: Account) {
        if isViewLoaded {
            reload(sections: [.top])
        }
    }

    // MARK: - Home file delegate

    func didSelect(index: Int, files: [File]) {
        filePresenter.present(driveFileManager: driveFileManager, file: files[index], files: files, normalFolderHierarchy: false)
    }

    // MARK: - Top scrollable

    func scrollToTop() {
        if isViewLoaded {
            tableView.scrollToTop(animated: true, navigationController: nil)
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let switchDriveAccountViewController = (segue.destination as? UINavigationController)?.viewControllers[0] as? SwitchDriveViewController {
            switchDriveAccountViewController.delegate = (tabBarController as? SwitchDriveDelegate)
        }
    }
}
