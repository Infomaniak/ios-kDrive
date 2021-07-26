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
import InfomaniakCore
import kDriveCore
import UIKit

class PhotoListViewController: MultipleSelectionViewController {
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var headerImageView: UIImageView!
    @IBOutlet weak var headerTitleLabel: IKLabel!
    @IBOutlet weak var selectButtonsStackView: UIStackView!
    @IBOutlet weak var moveButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var moreButton: UIButton!

    private class GroupedPictures {
        let referenceDate: Date
        let dateComponents: DateComponents
        let sortMode: PhotoSortMode
        var pictures: [File]

        var formattedDate: String {
            return sortMode.dateFormatter.string(from: referenceDate)
        }

        init(referenceDate: Date, sortMode: PhotoSortMode) {
            self.referenceDate = referenceDate
            self.dateComponents = Calendar.current.dateComponents(sortMode.calendarComponents, from: referenceDate)
            self.sortMode = sortMode
            self.pictures = [File]()
        }
    }

    private var groupedPictures = [GroupedPictures]()
    private var pictures = [File]()
    private var page = 1
    private var hasNextPage = true
    private var isLargeTitle = true
    private var floatingPanelViewController: DriveFloatingPanelController?
    private lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)

    private var isLoading = true {
        didSet {
            collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    private var sortMode: PhotoSortMode = UserDefaults.shared.photoSortMode {
        didSet { updateSort() }
    }

    private var shouldLoadMore: Bool {
        return hasNextPage && !isLoading
    }

    private var numberOfColumns: Int {
        return UIDevice.current.orientation.isLandscape ? 5 : 3
    }

    private let footerIdentifier = "LoadingFooterView"
    private let headerIdentifier = "PhotoSectionHeaderView"

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return isLargeTitle ? .default : .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        headerTitleLabel.textColor = .white

        // Set up collection view
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(cellView: HomeLastPicCollectionViewCell.self)
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: footerIdentifier)
        collectionView.register(UINib(nibName: "PhotoSectionHeaderView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerIdentifier)
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionHeadersPinToVisibleBounds = true

        // Set up multiple selection gesture
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        collectionView.addGestureRecognizer(longPressGesture)
        rightBarButtonItems = navigationItem.rightBarButtonItems

        fetchNextPage()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setPhotosNavigationBar()
        navigationItem.title = KDriveStrings.Localizable.allPictures
        applyGradient(view: headerImageView)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.tintColor = nil
    }

    @IBAction func searchButtonPressed(_ sender: Any) {
        present(SearchViewController.instantiateInNavigationController(driveFileManager: driveFileManager, fileType: .imagesRow), animated: true)
    }

    @IBAction func sortButtonPressed(_ sender: UIBarButtonItem) {
        let floatingPanelViewController = DriveFloatingPanelController()
        let sortViewController = FloatingPanelPhotoSortViewController()

        sortViewController.selectedSortMode = sortMode
        sortViewController.delegate = self

        // sortViewController.isRemovalInteractionEnabled = true
        floatingPanelViewController.delegate = sortViewController

        floatingPanelViewController.set(contentViewController: sortViewController)
        floatingPanelViewController.track(scrollView: sortViewController.tableView)
        present(floatingPanelViewController, animated: true)
    }

    func applyGradient(view: UIImageView) {
        let gradient = CAGradientLayer()
        let bounds = view.frame
        gradient.frame = bounds
        gradient.colors = [UIColor.black.withAlphaComponent(0.8).cgColor, UIColor.clear.cgColor]
        let renderer = UIGraphicsImageRenderer(size: gradient.frame.size)
        view.image = renderer.image { ctx in
            gradient.render(in: ctx.cgContext)
        }.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
    }

    private func setPhotosNavigationBar() {
        navigationController?.navigationBar.layoutMargins.left = 16
        navigationController?.navigationBar.layoutMargins.right = 16
        navigationController?.navigationBar.tintColor = isLargeTitle ? nil : .white
        let largeTitleStyle = TextStyle.header1
        let largeTitleTextAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: largeTitleStyle.color, .font: largeTitleStyle.font]
        let titleStyle = TextStyle.header3
        let titleTextAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white, .font: titleStyle.font]
        if #available(iOS 13.0, *) {
            let navbarAppearance = UINavigationBarAppearance()
            navbarAppearance.configureWithTransparentBackground()
            navbarAppearance.shadowImage = UIImage()
            navbarAppearance.titleTextAttributes = titleTextAttributes
            navbarAppearance.largeTitleTextAttributes = largeTitleTextAttributes

            navigationController?.navigationBar.standardAppearance = navbarAppearance
            navigationController?.navigationBar.compactAppearance = navbarAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navbarAppearance
        } else {
            navigationController?.navigationBar.isTranslucent = true
            navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
            navigationController?.navigationBar.shadowImage = UIImage()
            navigationController?.navigationBar.titleTextAttributes = titleTextAttributes
            navigationController?.navigationBar.largeTitleTextAttributes = largeTitleTextAttributes
        }
    }

    func forceRefresh() {
        page = 1
        pictures = []
        groupedPictures = []
        fetchNextPage()
    }

    func fetchNextPage() {
        isLoading = true
        driveFileManager?.getLastPictures(page: page) { response, _ in
            if let fetchedPictures = response {
                self.collectionView.performBatchUpdates {
                    self.insertAndSort(pictures: fetchedPictures, updateCollection: true)
                }

                self.pictures += fetchedPictures
                self.showEmptyView(.noImages)
                self.page += 1
                self.hasNextPage = fetchedPictures.count == DriveApiFetcher.itemPerPage
            }
            self.isLoading = false
            if self.groupedPictures.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
                self.hasNextPage = false
                self.showEmptyView(.noNetwork, showButton: true)
            }
        }
    }

    func showEmptyView(_ type: EmptyTableView.EmptyTableViewType, showButton: Bool = false) {
        if groupedPictures.isEmpty {
            let background = EmptyTableView.instantiate(type: type, button: showButton, setCenteringEnabled: true)
            background.actionHandler = { _ in
                self.forceRefresh()
            }
            collectionView.backgroundView = background
        } else {
            collectionView.backgroundView = nil
        }
    }

    private func insertAndSort(pictures: [File], updateCollection: Bool) {
        let sortMode = self.sortMode
        for picture in pictures {
            let currentDateComponents = Calendar.current.dateComponents(sortMode.calendarComponents, from: picture.lastModifiedDate)

            var currentSectionIndex: Int!
            var currentYearMonth: GroupedPictures!
            let lastYearMonth = groupedPictures.last
            if lastYearMonth?.dateComponents == currentDateComponents {
                currentYearMonth = lastYearMonth
                currentSectionIndex = groupedPictures.count - 1
            } else if let yearMonthIndex = groupedPictures.firstIndex(where: { $0.dateComponents == currentDateComponents }) {
                currentYearMonth = groupedPictures[yearMonthIndex]
                currentSectionIndex = yearMonthIndex
            } else {
                currentYearMonth = GroupedPictures(referenceDate: picture.lastModifiedDate, sortMode: sortMode)
                groupedPictures.append(currentYearMonth)
                currentSectionIndex = groupedPictures.count - 1
                if updateCollection {
                    collectionView.insertSections([currentSectionIndex + 1])
                }
            }
            currentYearMonth.pictures.append(picture)
            if updateCollection {
                collectionView.insertItems(at: [IndexPath(row: currentYearMonth.pictures.count - 1, section: currentSectionIndex + 1)])
            }
        }
    }

    private func updateSort() {
        UserDefaults.shared.photoSortMode = sortMode
        groupedPictures = []
        insertAndSort(pictures: pictures, updateCollection: false)
        collectionView.reloadData()
    }

    class func instantiate() -> PhotoListViewController {
        return Storyboard.menu.instantiateViewController(withIdentifier: "PhotoListViewController") as! PhotoListViewController
    }

    // MARK: - Multiple selection

    override func toggleMultipleSelection() {
        if selectionMode {
            navigationItem.title = nil
            selectButtonsStackView.isHidden = false
            headerTitleLabel.font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 22), weight: .bold)
            collectionView.allowsMultipleSelection = true
            navigationController?.navigationBar.prefersLargeTitles = false
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(cancelMultipleSelection))
            navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveStrings.Localizable.buttonClose
            navigationItem.rightBarButtonItems = nil
            let generator = UIImpactFeedbackGenerator()
            generator.prepare()
            generator.impactOccurred()
        } else {
            deselectAllChildren()
            selectButtonsStackView.isHidden = true
            headerTitleLabel.style = .header2
            headerTitleLabel.textColor = .white
            scrollViewDidScroll(collectionView)
            collectionView.allowsMultipleSelection = false
            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.title = KDriveStrings.Localizable.allPictures
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItems = rightBarButtonItems
        }
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
    }

    override func getItem(at indexPath: IndexPath) -> File? {
        guard indexPath.section - 1 < groupedPictures.count else {
            return nil
        }
        let pictures = groupedPictures[indexPath.section - 1].pictures
        guard indexPath.row < pictures.count else {
            return nil
        }
        return pictures[indexPath.row]
    }

    override func getAllItems() -> [File] {
        return pictures
    }

    override func setSelectedCells() {
        if selectionMode && !selectedItems.isEmpty {
            for i in 0..<groupedPictures.count {
                let pictures = groupedPictures[i].pictures
                for j in 0..<pictures.count where selectedItems.contains(pictures[j]) {
                    collectionView.selectItem(at: IndexPath(row: j, section: i), animated: false, scrollPosition: .centeredVertically)
                }
            }
        }
    }

    override func setSelectionButtonsEnabled(_ enabled: Bool) {
        moveButton.isEnabled = enabled
        deleteButton.isEnabled = enabled
        moreButton.isEnabled = enabled
    }

    override func updateSelectedCount() {
        headerTitleLabel.text = KDriveStrings.Localizable.fileListMultiSelectedTitle(selectedItems.count)
    }

    @IBAction func moveButtonPressed(_ sender: Any) {
        moveSelectedItems()
    }

    @IBAction func deleteButtonPressed(_ sender: Any) {
        deleteSelectedItems()
    }

    @IBAction func moreButtonPressed(_ sender: Any) {
        showMenuForSelection()
    }

    override func getNewChanges() {
        // TODO: Update collection view after action
    }

    // MARK: - Scroll view delegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        isLargeTitle = UIApplication.shared.statusBarOrientation.isPortrait ? (scrollView.contentOffset.y <= -UIConstants.largeTitleHeight) : false
        headerView.isHidden = isLargeTitle
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionHeadersPinToVisibleBounds = isLargeTitle
        navigationController?.navigationBar.tintColor = isLargeTitle ? nil : .white
        navigationController?.setNeedsStatusBarAppearanceUpdate()

        for headerView in collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) {
            if let headerView = headerView as? PhotoSectionHeaderView {
                let position = collectionView.convert(headerView.frame.origin, to: view)
                headerView.titleLabel.isHidden = position.y < headerTitleLabel.frame.minY && !isLargeTitle
            }
        }
        if !selectionMode {
            // Disable this behavior in selection mode because we reuse the view
            if let indexPath = collectionView.indexPathForItem(at: collectionView.convert(CGPoint(x: headerTitleLabel.frame.minX, y: headerTitleLabel.frame.maxY), from: headerTitleLabel)) {
                headerTitleLabel.text = groupedPictures[indexPath.section - 1].formattedDate
            } else if !groupedPictures.isEmpty && (headerTitleLabel.text?.isEmpty ?? true) {
                headerTitleLabel.text = groupedPictures[0].formattedDate
            }
        }

        // Infinite scroll
        let scrollPosition = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height - collectionView.frame.size.height
        if scrollPosition > contentHeight && shouldLoadMore {
            fetchNextPage()
        }
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        guard let driveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
        forceRefresh()
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource

extension PhotoListViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return groupedPictures.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 0
        } else {
            return groupedPictures[section - 1].pictures.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: HomeLastPicCollectionViewCell.self, for: indexPath)
        cell.configureWith(file: getItem(at: indexPath)!, roundedCorners: false, selectionMode: selectionMode)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if section == numberOfSections(in: collectionView) - 1 && isLoading {
            return CGSize(width: collectionView.frame.width, height: 80)
        } else {
            return .zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 0 {
            return .zero
        } else {
            return CGSize(width: collectionView.frame.width, height: 50)
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionFooter {
            let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: footerIdentifier, for: indexPath)
            let indicator = UIActivityIndicatorView(style: .gray)
            indicator.hidesWhenStopped = true
            indicator.color = KDriveAsset.loaderDarkerDefaultColor.color
            if isLoading {
                indicator.startAnimating()
            } else {
                indicator.stopAnimating()
            }
            footerView.addSubview(indicator)
            indicator.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
            ])
            return footerView
        } else {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: headerIdentifier, for: indexPath) as! PhotoSectionHeaderView
            if indexPath.section > 0 {
                let yearMonth = groupedPictures[indexPath.section - 1]
                headerView.titleLabel.text = yearMonth.formattedDate
            }
            return headerView
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if selectionMode {
            selectChild(at: indexPath)
        } else if let picture = getItem(at: indexPath) {
            filePresenter.present(driveFileManager: driveFileManager, file: picture, files: pictures, normalFolderHierarchy: false)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if selectionMode {
            deselectChild(at: indexPath)
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension PhotoListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let collectionViewLayout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return .zero
        }
        let width = collectionView.frame.width - collectionViewLayout.minimumInteritemSpacing * CGFloat(numberOfColumns - 1)
        let cellWidth = width / CGFloat(numberOfColumns)
        return CGSize(width: floor(cellWidth), height: floor(cellWidth))
    }
}

// MARK: - Photo sort delegate

extension PhotoListViewController: PhotoSortDelegate {
    func didSelect(sortMode: PhotoSortMode) {
        self.sortMode = sortMode
    }
}
