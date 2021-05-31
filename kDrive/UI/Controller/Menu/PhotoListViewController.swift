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

class PhotoListViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var headerImageView: UIImageView!
    @IBOutlet weak var headerTitleLabel: IKLabel!

    private let dateFormatter = DateFormatter()
    private class GroupedPictures {
        let referenceDate: Date
        let dateComponents: DateComponents
        var pictures: [File]

        init(referenceDate: Date) {
            self.referenceDate = referenceDate
            dateComponents = Calendar.current.dateComponents([.year, .month], from: referenceDate)
            self.pictures = [File]()
        }
    }

    private var pictureForYearMonth = [GroupedPictures]()
    private var pictures = [File]()
    private var page = 1
    private var hasNextPage = true
    private var isLoading = true {
        didSet {
            collectionView?.collectionViewLayout.invalidateLayout()
        }
    }
    private var isLargeTitle = true
    private lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)
    private var floatingPanelViewController: DriveFloatingPanelController?

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

    var driveFileManager: DriveFileManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        headerTitleLabel.textColor = .white
        dateFormatter.dateFormat = KDriveStrings.Localizable.photosHeaderDateFormat
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(cellView: HomeLastPicCollectionViewCell.self)
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: footerIdentifier)
        collectionView.register(UINib(nibName: "PhotoSectionHeaderView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerIdentifier)
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionHeadersPinToVisibleBounds = true
        fetchNextPage()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setPhotosNavigationBar()
        navigationItem.title = KDriveStrings.Localizable.allPictures
        applyGradient(view: headerImageView)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.tintColor = nil
    }

    @IBAction func searchButtonPressed(_ sender: Any) {
        present(SearchFileViewController.instantiateInNavigationController(driveFileManager: driveFileManager, fileType: .imagesRow), animated: true)
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
        if #available(iOS 13.0, *) {
            let navbarAppearance = UINavigationBarAppearance()
            navbarAppearance.configureWithTransparentBackground()
            navbarAppearance.shadowImage = UIImage()
            let largeTitleStyle = TextStyle.header1
            let titleStyle = TextStyle.header3
            navbarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white, .font: titleStyle.font]
            navbarAppearance.largeTitleTextAttributes = [.foregroundColor: largeTitleStyle.color, .font: largeTitleStyle.font]

            navigationController?.navigationBar.standardAppearance = navbarAppearance
            navigationController?.navigationBar.compactAppearance = navbarAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navbarAppearance
        } else {
            navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
            navigationController?.navigationBar.shadowImage = UIImage()
        }
    }

    func forceRefresh() {
        page = 1
        pictures = []
        pictureForYearMonth = []
        fetchNextPage()
    }

    func fetchNextPage() {
        isLoading = true
        driveFileManager?.apiFetcher.getLastPictures(page: page) { (response, error) in
            if let fetchedPictures = response?.data {

                self.collectionView.performBatchUpdates {
                    for picture in fetchedPictures {
                        let currentDateComponents = Calendar.current.dateComponents([.year, .month], from: picture.lastModifiedDate)

                        var currentSectionIndex: Int!
                        var currentYearMonth: GroupedPictures!
                        let lastYearMonth = self.pictureForYearMonth.last
                        if lastYearMonth?.dateComponents == currentDateComponents {
                            currentYearMonth = lastYearMonth
                            currentSectionIndex = self.pictureForYearMonth.count - 1
                        } else if let yearMonthIndex = self.pictureForYearMonth.firstIndex(where: { $0.dateComponents == currentDateComponents }) {
                            currentYearMonth = self.pictureForYearMonth[yearMonthIndex]
                            currentSectionIndex = yearMonthIndex
                        } else {
                            currentYearMonth = GroupedPictures(referenceDate: picture.lastModifiedDate)
                            self.pictureForYearMonth.append(currentYearMonth)
                            currentSectionIndex = self.pictureForYearMonth.count - 1
                            self.collectionView.insertSections([currentSectionIndex + 1])
                        }
                        currentYearMonth.pictures.append(picture)
                        self.collectionView.insertItems(at: [IndexPath(row: currentYearMonth.pictures.count - 1, section: currentSectionIndex + 1)])
                    }
                } completion: { done in

                }

                self.pictures += fetchedPictures
                self.showEmptyView(.noImages)
                self.page += 1
                self.hasNextPage = fetchedPictures.count == DriveApiFetcher.itemPerPage
                self.driveFileManager.setLocalFiles(self.pictures, root: DriveFileManager.lastPicturesRootFile)
            }
            self.isLoading = false
            if self.pictureForYearMonth.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
                self.hasNextPage = false
                self.showEmptyView(.noNetwork, showButton: true)
            }
        }
    }

    func showEmptyView(_ type: EmptyTableView.EmptyTableViewType, showButton: Bool = false) {
        if pictureForYearMonth.isEmpty {
            let background = EmptyTableView.instantiate(type: type, button: showButton, setCenteringEnabled: true)
            background.actionHandler = { _ in
                self.forceRefresh()
            }
            collectionView.backgroundView = background
        } else {
            collectionView.backgroundView = nil
        }
    }

    class func instantiate() -> PhotoListViewController {
        return UIStoryboard(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "PhotoListViewController") as! PhotoListViewController
    }

    // MARK: - Scroll view delegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if #available(iOS 13.0, *) {
            isLargeTitle = UIDevice.current.orientation.isPortrait ? (scrollView.contentOffset.y <= -UIConstants.largeTitleHeight) : false
            headerView.isHidden = isLargeTitle
            (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionHeadersPinToVisibleBounds = isLargeTitle
            navigationController?.navigationBar.tintColor = isLargeTitle ? nil : .white
            navigationController?.setNeedsStatusBarAppearanceUpdate()
        }

        for headerView in collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) {
            if let headerView = headerView as? PhotoSectionHeaderView {
                let position = collectionView.convert(headerView.frame.origin, to: view)
                headerView.titleLabel.isHidden = position.y < headerTitleLabel.frame.minY && !isLargeTitle
            }
        }
        if let indexPath = collectionView.indexPathForItem(at: collectionView.convert(CGPoint(x: headerView.frame.minX, y: headerView.frame.maxY), from: headerView)) {
            headerTitleLabel.text = dateFormatter.string(from: pictureForYearMonth[indexPath.section - 1].referenceDate)
        } else if pictureForYearMonth.count > 0 && headerTitleLabel.text == "" {
            headerTitleLabel.text = dateFormatter.string(from: pictureForYearMonth[0].referenceDate)
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
        return pictureForYearMonth.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 0
        } else {
            return pictureForYearMonth[section - 1].pictures.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: HomeLastPicCollectionViewCell.self, for: indexPath)
        cell.configureWith(file: pictureForYearMonth[indexPath.section - 1].pictures[indexPath.row])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if section == numberOfSections(in: collectionView) - 1 && isLoading {
            return CGSize(width: collectionView.frame.width, height: 80)
        } else {
            return CGSize.zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 0 {
            return CGSize.zero
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
                let yearMonth = pictureForYearMonth[indexPath.section - 1]
                headerView.titleLabel.text = dateFormatter.string(from: yearMonth.referenceDate)
            }
            return headerView
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        filePresenter.present(driveFileManager: driveFileManager, file: pictureForYearMonth[indexPath.section - 1].pictures[indexPath.row], files: pictures, normalFolderHierarchy: false)
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
