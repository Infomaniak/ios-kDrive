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

    private var files = [File]()
    private var page = 1
    private var hasNextPage = true
    private var isLoading = true
    private var isLargeTitle = true {
        didSet { updateNavBarMode() }
    }
    private var footerView: UICollectionReusableView?
    private lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)
    private var floatingPanelViewController: DriveFloatingPanelController?

    private var shouldLoadMore: Bool {
        return hasNextPage && !isLoading
    }

    private var numberOfColumns: Int {
        return UIDevice.current.orientation.isLandscape ? 5 : 3
    }

    private let footerIdentifier = "LoadingFooterView"

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return isLargeTitle ? .default : .lightContent
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNavBarMode()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.tintColor = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(cellView: HomeLastPicCollectionViewCell.self)
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: footerIdentifier)

        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationItem.title = KDriveStrings.Localizable.allPictures
        if #available(iOS 13.0, *) {
            let navigationAppearance = UINavigationBarAppearance()
            navigationAppearance.configureWithTransparentBackground()
            navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            navigationAppearance.backgroundImage = generateGradient()
            navigationItem.standardAppearance = navigationAppearance
            navigationItem.compactAppearance = navigationAppearance
            updateNavBarMode()
        }

        fetchNextPage()
    }

    func generateGradient() -> UIImage? {
        guard let navigationBar = navigationController?.navigationBar else {
            return nil
        }
        let gradient = CAGradientLayer()
        var bounds = navigationBar.bounds
        bounds.size.height += UIApplication.shared.statusBarFrame.size.height
        gradient.frame = bounds
        gradient.colors = [UIColor.black.withAlphaComponent(0.5).cgColor, UIColor.clear.cgColor]
        let renderer = UIGraphicsImageRenderer(size: gradient.frame.size)
        return renderer.image { ctx in
            gradient.render(in: ctx.cgContext)
        }.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
    }

    func updateNavBarMode() {
        navigationController?.navigationBar.tintColor = isLargeTitle ? nil : .white
        setNeedsStatusBarAppearanceUpdate()
    }

    func fetchNextPage() {
        footerView?.isHidden = false
        isLoading = true
        AccountManager.instance.currentDriveFileManager.apiFetcher.getLastPictures(page: page) { (response, error) in
            if let data = response?.data {
                let lastIndex = self.files.count
                self.files += data
                self.collectionView.insertItems(at: (lastIndex..<self.files.count).map { IndexPath(row: $0, section: 0) })
                self.page += 1
                self.hasNextPage = data.count == DriveApiFetcher.itemPerPage
                AccountManager.instance.currentDriveFileManager.setLocalFiles(self.files, root: DriveFileManager.lastPicturesRootFile)
            }
            self.footerView?.isHidden = true
            self.isLoading = false
        }
    }

    class func instantiate() -> PhotoListViewController {
        return UIStoryboard(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "PhotoListViewController") as! PhotoListViewController
    }

    // MARK: - Scroll view delegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if #available(iOS 13.0, *) {
            isLargeTitle = UIDevice.current.orientation.isPortrait ? (scrollView.contentOffset.y <= -UIConstants.largeTitleHeight) : false
        }

        // Infinite scroll
        let scrollPosition = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height - collectionView.frame.size.height
        if scrollPosition > contentHeight && shouldLoadMore {
            fetchNextPage()
        }
    }

}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource
extension PhotoListViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return files.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: HomeLastPicCollectionViewCell.self, for: indexPath)
        cell.configureWith(file: files[indexPath.row])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 80)
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if footerView == nil {
            let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: footerIdentifier, for: indexPath)
            let indicator = UIActivityIndicatorView(style: .gray)
            indicator.startAnimating()
            footerView.addSubview(indicator)
            indicator.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
                ])
            self.footerView = footerView
        }
        return footerView!
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        filePresenter.present(driveFileManager: AccountManager.instance.currentDriveFileManager, file: files[indexPath.row], files: files, normalFolderHierarchy: false)
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
        return CGSize(width: cellWidth, height: cellWidth)
    }
}
