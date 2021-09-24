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
import kDriveCore
import UIKit
/*
protocol HomeFileDelegate: AnyObject {
    func didSelect(index: Int, files: [File])
}

class HomeTableViewController: UITableViewController, SwitchDriveDelegate, SwitchAccountDelegate, HomeFileDelegate, TopScrollable {
    private enum HomeSection: Differentiable {
        case top
        case recentFiles
    }

    private enum HomeTopRows {
        case offline
        case drive
        case search
        case insufficientStorage
        case uploadsInProgress
        case recentFilesSelector
    }

    private enum RecentFileRows {
        case recentFiles
    }

    private var sections = [HomeSection]()
    private var topRows = [HomeTopRows]()

    private lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)

    private var uploadCountManager: UploadCountManager!
    private var filesObserver: ObservationToken?
    private var needsContentUpdate = false
    private var showInsufficientStorage = true
    private var lastUpdate = Date()
    private let updateDelay: TimeInterval = 60 // 1 minute

    private var floatingPanelViewController: DriveFloatingPanelController?

    private var navbarHeight: CGFloat {
        return navigationController?.navigationBar.frame.height ?? 0
    }

    var driveFileManager: DriveFileManager! {
        didSet {
            observeUploadCount()
        }
    }

    private var offlineFilesController: HomeOfflineFilesController!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never

        tableView.register(cellView: DriveSwitchTableViewCell.self)
        tableView.register(cellView: EmptyTableViewCell.self)

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
        if let refreshControl = tableView.refreshControl {
            refreshControl.bounds = refreshControl.bounds.offsetBy(dx: 0, dy: -24)
        }

        initViewWithCurrentDrive()

        // Table view footer

        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] status in
            DispatchQueue.main.async {
                self.reload(sections: [.top])
                if status != .offline {}
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

        updateContentIfNeeded()

        reload(sections: [.top])
        updateNavbarAppearance()
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.shadowImage = nil
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.barTintColor = nil
        navigationController?.navigationBar.titleTextAttributes = nil
        navigationController?.navigationBar.alpha = 1
        navigationController?.navigationBar.isUserInteractionEnabled = true
        navigationController?.navigationBar.layoutIfNeeded()
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
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
        if !needsContentUpdate && Date().timeIntervalSince(lastUpdate) > updateDelay {}
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

        // Reload table view
        updateSectionList()
        updateTopRows()
        tableView.reloadData()
    }

    private func observeUploadCount() {
        guard driveFileManager != nil else { return }
        uploadCountManager = UploadCountManager(driveFileManager: driveFileManager) { [weak self] in
            guard let self = self, self.isViewLoaded else { return }
            if let index = self.topRows.firstIndex(where: { $0 == .uploadsInProgress }),
               let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? UploadsInProgressTableViewCell {
                if self.uploadCountManager.uploadCount > 0 {
                    // Update cell
                    cell.setUploadCount(self.uploadCountManager.uploadCount)
                } else {
                    // Delete cell
                    self.reload(sections: [.top])
                }
            } else {
                // Add cell
                self.reload(sections: [.top])
            }
        }
    }

    private func updateSectionList() {
        sections = [.top, .recentFiles]
    }

    private func updateTopRows() {
        if ReachabilityListener.instance.currentStatus == .offline {
            topRows = [.offline, .drive, .search]
        } else {
            topRows = [.drive, .search, .recentFilesSelector]
        }

        if uploadCountManager != nil && uploadCountManager.uploadCount > 0 {
            topRows.append(.uploadsInProgress)
        }

        guard driveFileManager != nil && driveFileManager.drive.size > 0 else {
            return
        }
        let storagePercentage = Double(driveFileManager.drive.usedSize) / Double(driveFileManager.drive.size) * 100
        if (storagePercentage > UIConstants.insufficientStorageMinimumPercentage) && showInsufficientStorage {
            topRows.append(.insufficientStorage)
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

        // Reload sections
        let indexSet = sectionsToReload.compactMap { sections.firstIndex(of: $0) }
        tableView.reloadSections(IndexSet(indexSet), with: .automatic)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sections[section] {
        case .top:
            return 0
        case .recentFiles:
            return 33
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
        case .recentFiles:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .top:
            switch topRows[indexPath.row] {
            case .offline:
                let cell = tableView.dequeueReusableCell(type: DriveSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.selectionStyle = .none
                return cell
            case .drive:
                let cell = tableView.dequeueReusableCell(type: DriveSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.configureWith(drive: driveFileManager.drive)
                return cell
            case .search:
                let cell = tableView.dequeueReusableCell(type: DriveSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                return cell
            case .insufficientStorage:
                let cell = tableView.dequeueReusableCell(type: DriveSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                return cell
            case .uploadsInProgress:
                let cell = tableView.dequeueReusableCell(type: DriveSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                return cell
            case .recentFilesSelector:
                return UITableViewCell()
            }
        case .recentFiles:
            return UITableViewCell()
        }
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .top:
            return nil
        case .recentFiles:
            return HomeTitleView.instantiate(title: KDriveStrings.Localizable.homeLastActivities)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .top:
            switch topRows[indexPath.row] {
            case .offline, .insufficientStorage, .recentFilesSelector:
                return
            case .uploadsInProgress:
                let uploadViewController = UploadQueueFoldersViewController.instantiate(driveFileManager: driveFileManager)
                navigationController?.pushViewController(uploadViewController, animated: true)
            case .drive:
                performSegue(withIdentifier: "switchDriveSegue", sender: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            case .search:
                present(SearchViewController.instantiateInNavigationController(driveFileManager: driveFileManager), animated: true)
            }
        case .recentFiles:
            return
        }
    }

    // MARK: - Scroll view delegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateNavbarAppearance()
    }

    private func updateNavbarAppearance() {
        let scrollOffset = tableView.contentOffset.y
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }
        if UIApplication.shared.statusBarOrientation.isPortrait {
            navigationItem.title = driveFileManager?.drive.name ?? ""
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
        tableView.reloadData()
        needsContentUpdate = true
        updateContentIfNeeded()
    }

    // MARK: - Switch account delegate

    func didSwitchCurrentAccount(_ newAccount: Account) {}

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
*/
