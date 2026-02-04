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
import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import UIKit

extension PhotoSortMode: Selectable {}

extension PhotoListViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        guard let multipleSelectionViewModel = viewModel.multipleSelectionViewModel else {
            return false
        }
        return multipleSelectionViewModel.isMultipleSelectionEnabled
    }
}

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

    private let footerIdentifier = "LoadingFooterView"
    private let headerIdentifier = "ReusableHeaderView"
    private var displayedSections = PhotoListViewModel.emptySections

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    private var photoListViewModel: PhotoListViewModel! {
        return viewModel as? PhotoListViewModel
    }

    private weak var currentNavigationController: UINavigationController?

    enum SelectionMode {
        case selecting
        case deselecting
        case none
    }

    var selectionMode: SelectionMode = .none
    var lastTouchPoint: CGPoint = .zero
    var startIndexPath: IndexPath?
    var initialTouchPoint: CGPoint?
    var displayLink: CADisplayLink?
    var scrollSpeed: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        headerView?.isHidden = true
        navigationItem.largeTitleDisplayMode = .never
        view.addSubview(headerImageView)
        view.addSubview(photoHeaderView)

        NSLayoutConstraint.activate([
            photoHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            photoHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            photoHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),

            headerImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            headerImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            headerImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            headerImageView.bottomAnchor.constraint(equalTo: photoHeaderView.bottomAnchor, constant: 16)
        ])

        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: photoHeaderView.frame.height, left: 0, bottom: 0, right: 0)
        collectionView.contentInset.top = photoHeaderView.frame.height
        collectionView.register(cellView: HomeLastPicCollectionViewCell.self)
        collectionView.register(UICollectionReusableView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: footerIdentifier)
        collectionView.register(UINib(nibName: "ReusableHeaderView", bundle: nil),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: headerIdentifier)
        let selectionPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleSelectionPan))
        selectionPanGesture.delegate = self
        collectionView.addGestureRecognizer(selectionPanGesture)

        selectView = photoHeaderView
        selectView?.delegate = self
        bindPhotoListViewModel()
    }

    override func getDisplayedFile(at indexPath: IndexPath) -> File? {
        return displayedSections[safe: indexPath.section]?.elements[safe: indexPath.item]
    }

    private func bindPhotoListViewModel() {
        photoListViewModel.$sections.receiveOnMain(store: &bindStore) { [weak self] newContent in
            self?.reloadCollectionViewWith(sections: newContent)
        }
    }

    func reloadCollectionViewWith(sections: [PhotoListViewModel.Section]) {
        let changeSet = StagedChangeset(source: displayedSections, target: sections)
        collectionView.reload(using: changeSet,
                              interrupt: { $0.changeCount > Endpoint.itemsPerPage },
                              setData: {
                                  self.displayedSections = $0
                                  scrollViewDidScroll(collectionView)
                              })
    }

    override func reloadCollectionViewWith(files: [File]) {
        displayedFiles = files
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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        currentNavigationController?.setInfomaniakAppearanceNavigationBar()
        currentNavigationController?.navigationBar.tintColor = nil
    }

    private func applyGradient(view: UIImageView) {
        let gradient = CAGradientLayer()
        let bounds = view.frame
        gradient.frame = bounds
        gradient.colors = [
            UIColor.black.withAlphaComponent(0.8).cgColor,
            UIColor.clear.cgColor
        ]
        let renderer = UIGraphicsImageRenderer(size: gradient.frame.size)
        view.image = renderer.image { ctx in
            gradient.render(in: ctx.cgContext)
        }.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
    }

    private func setPhotosNavigationBar() {
        navigationController?.navigationBar.layoutMargins.left = 16
        navigationController?.navigationBar.layoutMargins.right = 16
        navigationController?.navigationBar.tintColor = .white

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

        currentNavigationController = navigationController
    }

    override func showEmptyView(_ isShowing: Bool) {
        if isShowing {
            let background = EmptyTableView.instantiate(type: .noImages, button: false, setCenteringEnabled: true)
            background.actionHandler = { [weak self] _ in
                self?.viewModel.forceRefresh()
            }
            collectionView.backgroundView = background
        } else {
            collectionView.backgroundView = nil
        }
    }

    @objc override func forceRefresh() {
        guard viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == false else {
            viewModel.endRefreshing()
            return
        }
        Task {
            driveFileManager.removeLocalFiles(root: DriveFileManager.lastPicturesRootFile)
            super.forceRefresh()
        }
    }

    override func onFilePresented(_ file: File) {
        #if !ISEXTENSION
        filePresenter.present(for: file,
                              files: viewModel.files,
                              driveFileManager: viewModel.driveFileManager,
                              normalFolderHierarchy: viewModel.configuration.normalFolderHierarchy,
                              presentationOrigin: viewModel.configuration.presentationOrigin)
        #endif
    }

    // MARK: - Multiple selection

    override func toggleMultipleSelection(_ on: Bool) {
        if on {
            collectionView.refreshControl = nil
            navigationItem.title = nil
            photoHeaderView.actionsView.isHidden = false
            headerTitleLabel.font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 22), weight: .bold)
            collectionView.allowsMultipleSelection = true
            let generator = UIImpactFeedbackGenerator()
            generator.prepare()
            generator.impactOccurred()
        } else {
            collectionView.refreshControl = refreshControl
            photoHeaderView.actionsView.isHidden = true
            headerTitleLabel.style = .header2
            headerTitleLabel.textColor = .white
            collectionView.allowsMultipleSelection = false
            navigationItem.title = viewModel.title
            scrollViewDidScroll(collectionView)
        }
        collectionView.reloadSections(IndexSet(integersIn: 0 ..< numberOfSections(in: collectionView)))
    }

    func updateTitle(_ count: Int) {
        headerTitleLabel.text = KDriveResourcesStrings.Localizable.fileListMultiSelectedTitle(count)
    }

    @objc func handleSelectionPan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: collectionView)

        guard let multipleSelectionViewModel = photoListViewModel.multipleSelectionViewModel,
              let indexPath = collectionView.indexPathForItem(at: location),
              let file = getDisplayedFile(at: indexPath) else { return }

        lastTouchPoint = location

        switch gesture.state {
        case .began:
            if multipleSelectionViewModel.selectedItems.contains(file) {
                selectionMode = .deselecting
            } else {
                selectionMode = .selecting
            }

            startIndexPath = indexPath
            initialTouchPoint = location
            startDisplayLink()

        case .changed:
            updateScrollSpeed(for: lastTouchPoint)
            updateSelection(to: location, current: indexPath)

        case .ended, .cancelled, .failed:
            initialTouchPoint = nil
            stopDisplayLink()
            selectionMode = .none

        default:
            break
        }
    }

    func updateSelection(to location: CGPoint, current: IndexPath) {
        guard let start = startIndexPath,
              let multipleSelectionViewModel = photoListViewModel.multipleSelectionViewModel else { return }

        let contentRect = CGRect(origin: .zero, size: collectionView.contentSize)
        let attributes = collectionView.collectionViewLayout.layoutAttributesForElements(in: contentRect) ?? []

        let sortedAttributes = attributes.sorted {
            if abs($0.center.y - $1.center.y) > 1 {
                return $0.center.y < $1.center.y
            } else {
                return $0.center.x < $1.center.x
            }
        }

        guard let startIndex = sortedAttributes.firstIndex(where: { $0.indexPath == start }),
              let endIndex = sortedAttributes.firstIndex(where: { $0.indexPath == current }),
              startIndex != endIndex else { return }

        let range = startIndex <= endIndex
            ? startIndex ... endIndex
            : endIndex ... startIndex

        for attributes in sortedAttributes[range] {
            let indexPath = attributes.indexPath
            guard let file = getDisplayedFile(at: indexPath) else { return }

            switch selectionMode {
            case .selecting:
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                multipleSelectionViewModel.didSelectFile(file, at: indexPath)

            case .deselecting:
                collectionView.deselectItem(at: indexPath, animated: false)
                multipleSelectionViewModel.didDeselectFile(file, at: indexPath)

            default:
                break
            }
        }
    }

    func updateScrollSpeed(for locationInContent: CGPoint) {
        let visibleY = locationInContent.y - collectionView.contentOffset.y

        let threshold = collectionView.bounds.height * 0.1
        let maxSpeed: CGFloat = 25

        if visibleY < threshold {
            let distance = threshold - visibleY
            let percent = min(distance / threshold, 1)
            scrollSpeed = -maxSpeed * percent * percent
        } else if visibleY > collectionView.bounds.height - threshold {
            let distance = visibleY - (collectionView.bounds.height - threshold)
            let percent = min(distance / threshold, 1)
            scrollSpeed = maxSpeed * percent * percent
        } else {
            scrollSpeed = 0
        }
    }

    func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(handleAutoScroll))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        scrollSpeed = 0
    }

    @objc func handleAutoScroll() {
        guard scrollSpeed != 0 else { return }

        var offset = collectionView.contentOffset
        offset.y += scrollSpeed

        offset.y = max(0, min(offset.y, collectionView.contentSize.height - collectionView.bounds.height))
        collectionView.setContentOffset(offset, animated: false)
    }

    // MARK: - Scroll view delegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let viewModel = photoListViewModel else { return }
        photoHeaderView.isHidden = false
        headerImageView.isHidden = false
        navigationController?.navigationBar.tintColor = .white
        navigationController?.setNeedsStatusBarAppearanceUpdate()

        for visibleHeaderView in collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) {
            if let reusableHeaderView = visibleHeaderView as? ReusableHeaderView {
                let position = collectionView.convert(reusableHeaderView.frame.origin, to: view)
                reusableHeaderView.titleLabel.isHidden = position.y < headerTitleLabel.frame.minY
            }
        }
        if viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == false {
            // Disable this behavior in selection mode because we reuse the view
            if let indexPath = collectionView.indexPathForItem(at: collectionView.convert(
                CGPoint(x: headerTitleLabel.frame.minX, y: headerTitleLabel.frame.maxY + 16),
                from: headerTitleLabel
            )) {
                if let section = displayedSections[safe: indexPath.section] {
                    headerTitleLabel.text = section.model.formattedDate
                } else {
                    headerTitleLabel.text = ""
                }
            } else if let firstSection = displayedSections.first, headerTitleLabel.text?.isEmpty ?? true {
                headerTitleLabel.text = firstSection.model.formattedDate
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
        guard let file = getDisplayedFile(at: indexPath) else {
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
            let reusableHeaderView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: headerIdentifier,
                for: indexPath
            ) as! ReusableHeaderView
            if indexPath.section > 0 {
                let yearMonth = displayedSections[indexPath.section].model
                reusableHeaderView.titleLabel.text = yearMonth.formattedDate
            }
            return reusableHeaderView
        }
    }

    // MARK: - State restoration

    override var currentSceneMetadata: [AnyHashable: Any] {
        [:]
    }
}
