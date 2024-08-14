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
import Combine
import DifferenceKit
import InfomaniakCore
import InfomaniakCoreUI
import kDriveCore
import kDriveResources
import UIKit

extension PhotoSortMode: Selectable {}

final class PhotoListViewController: FileListViewController {
    var headerTitleLabel: IKLabel {
        return photoHeaderView.titleLabel
    }

    lazy var headerImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    lazy var photoHeaderView: SelectView = {
        let selectView = SelectView.instantiate()
        selectView.translatesAutoresizingMaskIntoConstraints = false
        selectView.backgroundColor = .clear
        selectView.buttonTint = .white

        return selectView
    }()

    private var numberOfColumns: Int {
        let screenWidth = collectionView.bounds.width
        let maxColumns = Int(screenWidth / cellMaxWidth)
        return max(minColumns, maxColumns)
    }

    private var isLargeTitle = true
    private let minColumns = 3
    private let cellMaxWidth = 150.0
    private let footerIdentifier = "LoadingFooterView"
    private let headerIdentifier = "PhotoSectionHeaderView"
    private var displayedSections = PhotoListViewModel.emptySections

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return isLargeTitle ? .default : .lightContent
    }

    private var photoListViewModel: PhotoListViewModel! {
        return viewModel as? PhotoListViewModel
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(headerImageView)
        view.addSubview(photoHeaderView)
        selectView = photoHeaderView

        NSLayoutConstraint.activate([
            photoHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            photoHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            photoHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),

            headerImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            headerImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            headerImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            headerImageView.bottomAnchor.constraint(equalTo: photoHeaderView.bottomAnchor, constant: 0)
        ])

        (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing = 4
        (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumLineSpacing = 4
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: photoHeaderView.frame.height, left: 0, bottom: 0, right: 0)
        collectionView.register(cellView: HomeLastPicCollectionViewCell.self)
        collectionView.register(UICollectionReusableView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: footerIdentifier)
        collectionView.register(UINib(nibName: "PhotoSectionHeaderView", bundle: nil),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: headerIdentifier)
        selectView = photoHeaderView
        selectView?.delegate = self
        bindPhotoListViewModel()
    }

    private func bindPhotoListViewModel() {
        photoListViewModel.$sections.receiveOnMain(store: &bindStore) { [weak self] newContent in
            self?.reloadCollectionViewWith(sections: newContent)
        }
    }

    func reloadCollectionViewWith(sections: [PhotoListViewModel.Section]) {
        let changeSet = StagedChangeset(source: displayedSections, target: sections)
        collectionView.reload(using: changeSet, interrupt: { $0.changeCount > Endpoint.itemsPerPage }) { data in
            self.displayedSections = data
        }

        showEmptyView(.noImages)
        if let collectionView {
            scrollViewDidScroll(collectionView)
        }
    }

    override func reloadCollectionViewWith(files: [File]) {
        self.displayedFiles = files
        // We do not reload the collection view as it handles sections
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setPhotosNavigationBar()
        navigationItem.title = viewModel.title
        Task {
            try await viewModel.loadFiles()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        saveSceneState()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyGradient(view: headerImageView)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.tintColor = nil
    }

    private func applyGradient(view: UIImageView) {
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
        let largeTitleTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: largeTitleStyle.color,
            .font: largeTitleStyle.font
        ]
        let titleStyle = TextStyle.header3
        let titleTextAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white, .font: titleStyle.font]
        let navbarAppearance = UINavigationBarAppearance()
        navbarAppearance.configureWithTransparentBackground()
        navbarAppearance.shadowImage = UIImage()
        navbarAppearance.titleTextAttributes = titleTextAttributes
        navbarAppearance.largeTitleTextAttributes = largeTitleTextAttributes

        navigationController?.navigationBar.standardAppearance = navbarAppearance
        navigationController?.navigationBar.compactAppearance = navbarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navbarAppearance
    }

    func showEmptyView(_ type: EmptyTableView.EmptyTableViewType, showButton: Bool = false) {
        if displayedSections.isEmpty {
            let background = EmptyTableView.instantiate(type: type, button: showButton, setCenteringEnabled: true)
            background.actionHandler = { [weak self] _ in
                self?.viewModel.forceRefresh()
            }
            collectionView.backgroundView = background
        } else {
            collectionView.backgroundView = nil
        }
    }

    @objc override func forceRefresh() {
        Task {
            driveFileManager.removeLocalFiles(root: DriveFileManager.lastPicturesRootFile)
            super.forceRefresh()
        }
    }

    // MARK: - Multiple selection

    override func toggleMultipleSelection(_ on: Bool) {
        if on {
            navigationItem.title = nil
            photoHeaderView.actionsView.isHidden = false
            headerTitleLabel.font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 22), weight: .bold)
            collectionView.allowsMultipleSelection = true
            navigationController?.navigationBar.prefersLargeTitles = false
            let generator = UIImpactFeedbackGenerator()
            generator.prepare()
            generator.impactOccurred()
        } else {
            photoHeaderView.actionsView.isHidden = true
            headerTitleLabel.style = .header2
            headerTitleLabel.textColor = .white
            collectionView.allowsMultipleSelection = false
            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.title = viewModel.title
            scrollViewDidScroll(collectionView)
        }
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
    }

    func updateTitle(_ count: Int) {
        headerTitleLabel.text = KDriveResourcesStrings.Localizable.fileListMultiSelectedTitle(count)
    }

    // MARK: - Scroll view delegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let viewModel = photoListViewModel else { return }
        isLargeTitle = (view.window?.windowScene?.interfaceOrientation.isPortrait == true) ?
            (scrollView.contentOffset.y <= -UIConstants.largeTitleHeight) : false
        photoHeaderView.isHidden = isLargeTitle
        headerImageView.isHidden = isLargeTitle
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionHeadersPinToVisibleBounds = isLargeTitle
        navigationController?.navigationBar.tintColor = isLargeTitle ? nil : .white
        navigationController?.setNeedsStatusBarAppearanceUpdate()

        for visibleHeaderView in collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) {
            if let photoSectionHeaderView = visibleHeaderView as? PhotoSectionHeaderView {
                let position = collectionView.convert(photoSectionHeaderView.frame.origin, to: view)
                photoSectionHeaderView.titleLabel.isHidden = position.y < headerTitleLabel.frame.minY && !isLargeTitle
            }
        }
        if viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == false {
            // Disable this behavior in selection mode because we reuse the view
            if let indexPath = collectionView.indexPathForItem(at: collectionView.convert(
                CGPoint(x: headerTitleLabel.frame.minX, y: headerTitleLabel.frame.maxY),
                from: headerTitleLabel
            )) {
                headerTitleLabel.text = viewModel.sections[indexPath.section].model.formattedDate
            } else if !displayedSections.isEmpty && (headerTitleLabel.text?.isEmpty ?? true) {
                headerTitleLabel.text = displayedSections[0].model.formattedDate
            }
        }

        // Infinite scroll
        let scrollPosition = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height - collectionView.frame.size.height
        if scrollPosition > contentHeight {
            Task {
                try await viewModel.loadNextPageIfNeeded()
            }
        }
    }

    // MARK: - UICollectionViewDelegate, UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return displayedSections.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return displayedSections[section].elements.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: HomeLastPicCollectionViewCell.self, for: indexPath)
        guard let file = displayedSections[safe: indexPath.section]?.elements[indexPath.row] else {
            return cell
        }

        cell.configureWith(
            file: file,
            roundedCorners: false,
            selectionMode: viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForFooterInSection section: Int
    ) -> CGSize {
        if section == numberOfSections(in: collectionView) - 1 && viewModel.isLoading {
            return CGSize(width: collectionView.frame.width, height: 80)
        } else {
            return .zero
        }
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        if section == 0 {
            return .zero
        } else {
            return CGSize(width: collectionView.frame.width, height: 50)
        }
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionFooter {
            let footerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: footerIdentifier,
                for: indexPath
            )
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.hidesWhenStopped = true
            indicator.color = KDriveResourcesAsset.loaderDarkerDefaultColor.color
            if viewModel.isLoading {
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
            let photoSectionHeaderView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: headerIdentifier,
                for: indexPath
            ) as! PhotoSectionHeaderView
            if indexPath.section > 0 {
                let yearMonth = displayedSections[indexPath.section].model
                photoSectionHeaderView.titleLabel.text = yearMonth.formattedDate
            }
            return photoSectionHeaderView
        }
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    override func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard let collectionViewLayout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return .zero
        }
        let width = collectionView.frame.width - collectionViewLayout.minimumInteritemSpacing * CGFloat(numberOfColumns - 1)
        let cellWidth = floor(width / CGFloat(numberOfColumns))
        return CGSize(width: cellWidth, height: cellWidth)
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 4
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 4
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        return .zero
    }

    // MARK: - State restoration

    override var currentSceneMetadata: [AnyHashable: Any] {
        [:]
    }
}
