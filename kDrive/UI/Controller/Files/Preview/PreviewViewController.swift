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

import AVFoundation
import FloatingPanel
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import PDFKit
import SafariServices
import Sentry
import UIKit

@MainActor protocol PreviewContentCellDelegate: AnyObject {
    func updateNavigationBar()
    func setFullscreen(_ fullscreen: Bool?)
    func errorWhilePreviewing(fileId: Int, error: Error)
    func openWith(from: UIView)
}

final class PreviewViewController: UIViewController, PreviewContentCellDelegate, SceneStateRestorable {
    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var downloadQueue: DownloadQueueable

    @IBOutlet var collectionView: UICollectionView!
    private var previewFiles = [File]()
    private var previewErrors = [Int: PreviewError]()
    private var driveFileManager: DriveFileManager!
    private var normalFolderHierarchy = true
    private var initialLoading = true
    private var presentationOrigin = PresentationOrigin.fileList
    private var currentIndex = IndexPath(row: 0, section: 0) {
        didSet {
            setTitle()
            saveSceneState()
        }
    }

    var currentPreviewedFileId: Int {
        return currentFile.id
    }

    private var editButtonHidden: Bool {
        driveFileManager.isPublicShare
    }

    private var currentDownloadOperation: DownloadAuthenticatedOperation?
    private let pdfPageLabel = UILabel(frame: .zero)
    private var titleWidthConstraint: NSLayoutConstraint?
    private var titleHeightConstraint: NSLayoutConstraint?
    @IBOutlet var statusBarView: UIView!
    private var fullScreenPreview = false
    private var heightToHide = 0.0

    private var floatingPanelViewController: FloatingPanelController!
    private var fileInformationsViewController: FileActionsFloatingPanelViewController!

    private var currentFile: File {
        get {
            return previewFiles[currentIndex.row]
        }
        set {
            previewFiles[currentIndex.row] = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.collectionViewLayout = createFullscreenLayout()
        collectionView.register(cellView: NoPreviewCollectionViewCell.self)
        collectionView.register(cellView: DownloadingPreviewCollectionViewCell.self)
        collectionView.register(cellView: ImagePreviewCollectionViewCell.self)
        collectionView.register(cellView: PdfPreviewCollectionViewCell.self)
        collectionView.register(cellView: VideoCollectionViewCell.self)
        collectionView.register(cellView: OfficePreviewCollectionViewCell.self)
        collectionView.register(cellView: AudioCollectionViewCell.self)
        collectionView.register(cellView: CodePreviewCollectionViewCell.self)
        collectionView.contentInsetAdjustmentBehavior = .never

        floatingPanelViewController = DriveFloatingPanelController()
        floatingPanelViewController.isRemovalInteractionEnabled = false
        fileInformationsViewController = FileActionsFloatingPanelViewController(
            frozenFile: currentFile,
            driveFileManager: driveFileManager
        )

        fileInformationsViewController.presentingParent = self
        fileInformationsViewController.normalFolderHierarchy = normalFolderHierarchy
        fileInformationsViewController.presentationOrigin = presentationOrigin

        floatingPanelViewController.set(contentViewController: fileInformationsViewController)
        floatingPanelViewController.track(scrollView: fileInformationsViewController.collectionView)
        floatingPanelViewController.delegate = self

        if presentationOrigin == .activities {
            floatingPanelViewController.surfaceView.grabberHandle.isHidden = true
        }

        pdfPageLabel.font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .medium)
        pdfPageLabel.textColor = .white
        pdfPageLabel.textAlignment = .center
        pdfPageLabel.contentMode = .center
        pdfPageLabel.numberOfLines = 1
        pdfPageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pdfPageLabel)


        // Constraints
        titleWidthConstraint = pdfPageLabel.widthAnchor.constraint(equalToConstant: pdfPageLabel.frame.width)
        titleWidthConstraint?.isActive = true
        titleHeightConstraint = pdfPageLabel.heightAnchor.constraint(equalToConstant: pdfPageLabel.frame.height)
        titleHeightConstraint?.isActive = true
        let constraints = [
            pdfPageLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor)
        ]
        NSLayoutConstraint.activate(constraints)

        observeFileUpdated()
    }

    func createFullscreenLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .fractionalHeight(1.0))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal
        configuration.contentInsetsReference = .none
        let layout = UICollectionViewCompositionalLayout(section: section, configuration: configuration)
        return layout
    }

    @objc func tapPreview() {
        setFullscreen()
    }

    func observeFileUpdated() {
        driveFileManager?.observeFileUpdated(self, fileId: nil) { [weak self] file in
            guard !file.isInvalidated else { return }
            let frozenFile = file.freeze()
            Task { @MainActor in
                guard let self,
                      !self.currentFile.isInvalidated,
                      !file.isInvalidated,
                      self.currentFile.id == frozenFile.id else {
                    return
                }

                self.currentFile = frozenFile

                self.collectionView.endEditing(true)
                self.collectionView.reloadItems(at: [self.currentIndex])
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let backImage = makeImageWithCircle(
            icon: KDriveResourcesAsset.chevronLeft.image,
            circleDiameter: 44,
            iconSize: CGSize(width: 28, height: 28),
            circleColor: KDriveResourcesAsset.previewBackgroundColor.color.withAlphaComponent(0.4)
        )

        let backButtonAppearance = UIBarButtonItemAppearance(style: .plain)
        let navbarAppearance = UINavigationBarAppearance()
        navbarAppearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        navbarAppearance.backButtonAppearance = backButtonAppearance
        navbarAppearance.configureWithTransparentBackground()
        navbarAppearance.shadowImage = UIImage()
        navigationController?.navigationBar.standardAppearance = navbarAppearance
        navigationController?.navigationBar.compactAppearance = navbarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navbarAppearance

        if initialLoading {
            matomo.trackPreview(file: currentFile)

            collectionView.setNeedsLayout()
            collectionView.layoutIfNeeded()

            updateFileForCurrentIndex()

            collectionView.scrollToItem(at: currentIndex, at: .centeredVertically, animated: false)
            updateNavigationBar()
            downloadFileIfNeeded(at: currentIndex)
            initialLoading = false
        }
    }

    private func makeImageWithCircle(
        icon: UIImage,
        circleDiameter: CGFloat,
        iconSize: CGSize,
        circleColor: UIColor
    ) -> UIImage {
        let canvasSize = CGSize(width: circleDiameter, height: circleDiameter)

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: canvasSize)

            let circlePath = UIBezierPath(ovalIn: rect)
            circleColor.setFill()
            circlePath.fill()

            let iconImage = icon
                .withRenderingMode(.alwaysTemplate)
            let iconRect = CGRect(
                x: (canvasSize.width - iconSize.width) / 2.0,
                y: (canvasSize.height - iconSize.height) / 2.0,
                width: iconSize.width,
                height: iconSize.height
            )

            UIColor.white.setFill()
            UIColor.white.setStroke()
            iconImage.draw(in: iconRect, blendMode: .normal, alpha: 1.0)
        }

        return image.withRenderingMode(.alwaysOriginal)
    }

    private func updateFileForCurrentIndex() {
        fileInformationsViewController.updateAndObserveFile(withFileUid: currentFile.uid, driveFileManager: driveFileManager)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hideFloatingPanel(false)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        becomeFirstResponder()

        matomo.track(view: [MatomoUtils.View.preview.displayName, "File"])

        saveSceneState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideFloatingPanel(true)
        navigationController?.setNavigationBarHidden(false, animated: true)
        let currentCell = (collectionView.cellForItem(at: currentIndex) as? PreviewCollectionViewCell)
        currentCell?.didEndDisplaying()
        currentDownloadOperation?.cancel()
        previewErrors.values.compactMap { $0 as? OfficePreviewError }.forEach { $0.downloadTask?.cancel() }

        UIApplication.shared.endReceivingRemoteControlEvents()
        resignFirstResponder()
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        guard parent == nil else {
            return
        }

        floatingPanelViewController?.dismiss(animated: false)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let centerIndexPathBeforeRotate = currentIndex
        coordinator.animate { _ in
            self.collectionView.scrollToItem(at: centerIndexPathBeforeRotate, at: .centeredVertically, animated: false)
        }
    }

    override func remoteControlReceived(with event: UIEvent?) {
        guard let cell = collectionView.visibleCells.first as? AudioCollectionViewCell else { return }
        switch event?.subtype {
        case .remoteControlTogglePlayPause:
            cell.togglePlayPause()
        case .remoteControlPlay:
            cell.play()
        case .remoteControlPause:
            cell.pause()
        default:
            break
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        floatingPanelViewController.layout = FileFloatingPanelLayout(safeAreaInset: min(view.safeAreaInsets.bottom, 5))
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }

    override var prefersStatusBarHidden: Bool {
        return fullScreenPreview
    }

    private func setTitle() {
        navigationItem.title = currentFile.name
    }

    func updateNavigationBar() {
        guard !currentFile.isLocalVersionOlderThanRemote else {
            setNavbarStandard()
            return
        }

        switch currentFile.convertedType {
        case .pdf:
            if let pdfCell = (collectionView.cellForItem(at: currentIndex) as? PdfPreviewCollectionViewCell),
               let currentPage = pdfCell.pdfPreview.currentPage?.pageRef?.pageNumber,
               let totalPages = pdfCell.pdfPreview.document?.pageCount {
                setNavbarForPdf(currentPage: currentPage, totalPages: totalPages)
            } else {
                setNavbarStandard()
            }
        case .text, .code, .presentation, .spreadsheet, .form:
            if currentFile.isOfficeFile && currentFile.capabilities.canWrite {
                setNavbarForEditing()
            } else {
                setNavbarStandard()
            }
        case .url:
            setNavbarForOpening()
        default:
            setNavbarStandard()
        }
    }

    private func setNavbarStandard() {
        pdfPageLabel.isHidden = true
    }

    private func setNavbarForEditing() {
        pdfPageLabel.isHidden = true
    }

    private func setNavbarForOpening() {
        pdfPageLabel.isHidden = true
    }

    private func setNavbarForPdf(currentPage: Int, totalPages: Int) {
        pdfPageLabel.text = KDriveResourcesStrings.Localizable.previewPdfPages(currentPage, totalPages)
        pdfPageLabel.sizeToFit()
        titleWidthConstraint?.constant = pdfPageLabel.frame.width + 32
        let height = pdfPageLabel.frame.height + 16
        titleHeightConstraint?.constant = height
        pdfPageLabel.setNeedsUpdateConstraints()
        pdfPageLabel.layer.cornerRadius = height / 2
        pdfPageLabel.clipsToBounds = true
        pdfPageLabel.backgroundColor = KDriveResourcesAsset.previewBackgroundColor.color.withAlphaComponent(0.4)
        pdfPageLabel.isHidden = false
    }

    @objc private func editFile() {
        @InjectService var appRouter: AppNavigable

        guard !driveFileManager.isPublicShare else { return }
        matomo.track(eventWithCategory: .mediaPlayer, name: "edit")
        floatingPanelViewController.dismiss(animated: true)
        appRouter.presentOnlyOfficeViewController(driveFileManager: driveFileManager, file: currentFile, viewController: self)
    }

    @objc private func openFile() {
        guard currentFile.isBookmark else {
            return
        }

        floatingPanelViewController.dismiss(animated: false)
        FilePresenter(viewController: self).present(
            for: currentFile,
            files: [],
            driveFileManager: driveFileManager,
            normalFolderHierarchy: true
        ) { success in
            if !success {
                self.present(self.floatingPanelViewController, animated: false)
            }
        }
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    func setFullscreen(_ fullscreen: Bool? = nil) {
        if let value = fullscreen {
            fullScreenPreview = value
        } else {
            fullScreenPreview.toggle()
        }
        UIView.animate(withDuration: 0.2) {
            self.setNeedsStatusBarAppearanceUpdate()
            let hideStatusBar = CGAffineTransform(
                translationX: 0,
                y: self.fullScreenPreview ? -self.statusBarView.frame.height : 0
            )
            self.statusBarView.transform = hideStatusBar
        }
        UIView.animate(withDuration: 0.4) {

            let topInset = self.fullScreenPreview ? 0 : UIConstants.Padding.standard
            if let officeCell = self.collectionView.cellForItem(at: self.currentIndex) as? PreviewCollectionViewCell {
                officeCell.setTopInset(topInset)
            }
        }

        hideFloatingPanel(fullScreenPreview)
    }

    func hideFloatingPanel(_ hide: Bool) {
        if hide {
            if floatingPanelViewController.presentingViewController != nil {
                floatingPanelViewController.dismiss(animated: true)
            } else if floatingPanelViewController.parent != nil {
                floatingPanelViewController.removePanelFromParent(animated: true)
            }
            floatingPanelViewController.dismiss(animated: true)
        } else {
            if traitCollection.horizontalSizeClass == .regular {
                guard floatingPanelViewController.parent == nil else { return }
                floatingPanelViewController.addPanel(toParent: self, animated: true)
            } else {
                guard floatingPanelViewController.presentingViewController == nil else { return }
                present(floatingPanelViewController, animated: true)
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let centerCellIndexPath = collectionView.indexPathForItem(at: view.convert(view.center, to: collectionView)),
              currentIndex != centerCellIndexPath else {
            return
        }

        matomo.trackPreview(file: currentFile)

        let previousCell = (collectionView.cellForItem(at: currentIndex) as? PreviewCollectionViewCell)
        previousCell?.didEndDisplaying()

        currentIndex = centerCellIndexPath
        updateFileForCurrentIndex()

        updateNavigationBar()
        downloadFileIfNeeded(at: currentIndex)
    }

    func errorWhilePreviewing(fileId: Int, error: Error) {
        guard let index = previewFiles.firstIndex(where: { $0.id == fileId }) else {
            return
        }

        let file = previewFiles[index]
        if ConvertedType.documentTypes.contains(file.convertedType) {
            handleOfficePreviewError(error, previewIndex: index)
        } else if file.convertedType == .audio {
            handleAudioPreviewError(error, previewIndex: index)
        } else if file.convertedType == .video {
            handleVideoPreviewError(error, previewIndex: index)
        }

        // We have to delay reload because errorWhilePreviewing can be called when the collectionView requests a new cell in
        // cellForItemAt and iOS 18 seems unhappy about this.
        Task { @MainActor [weak self] in
            self?.collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        }
    }

    func handleAudioPreviewError(_ error: Error, previewIndex: Int) {
        let file = previewFiles[previewIndex]

        guard let avError = error as? AVError else {
            return
        }

        if avError.code == .fileFormatNotRecognized {
            previewErrors[file.id] = PreviewError(fileId: file.id, underlyingError: nil)
            guard file.isLocalVersionOlderThanRemote else { return }
            downloadFile(at: IndexPath(item: previewIndex, section: 0))
        } else {
            let previewError = PreviewError(fileId: file.id, underlyingError: avError)
            previewErrors[file.id] = previewError
        }
    }

    func handleVideoPreviewError(_ error: Error, previewIndex: Int) {
        let file = previewFiles[previewIndex]

        guard let videoError = error as? VideoPlayer.ErrorDomain,
              videoError == .incompatibleFile else {
            return
        }

        previewErrors[file.id] = PreviewError(fileId: file.id, underlyingError: nil)
    }

    func handleOfficePreviewError(_ error: Error, previewIndex: Int) {
        let safeFile = previewFiles[previewIndex].freezeIfNeeded()
        let previewError = OfficePreviewError(fileId: safeFile.id, pdfGenerationProgress: Progress(totalUnitCount: 10))

        PdfPreviewCache.shared.retrievePdf(forSafeFile: safeFile, driveFileManager: driveFileManager) { downloadTask in
            previewError.addDownloadTask(downloadTask)
            Task { @MainActor [weak self] in
                self?.collectionView.reloadItems(at: [IndexPath(item: previewIndex, section: 0)])
            }
        } completion: { url, error in
            previewError.removeDownloadTask()
            if let url {
                previewError.pdfUrl = url
            } else {
                previewError.underlyingError = error
            }
            Task { @MainActor [weak self] in
                self?.collectionView.reloadItems(at: [IndexPath(item: previewIndex, section: 0)])
            }
        }

        previewErrors[safeFile.id] = previewError
    }

    func openWith(from: UIView) {
        let frame = from.convert(from.bounds, to: view)
        floatingPanelViewController.dismiss(animated: true)
        if currentFile.isMostRecentDownloaded {
            FileActionsHelper.instance.openWith(file: currentFile, from: frame, in: view, delegate: self)
        } else {
            downloadToOpenWith { [weak self] in
                guard let self else { return }
                FileActionsHelper.instance.openWith(file: currentFile, from: frame, in: view, delegate: self)
            }
        }
    }

    private func downloadToOpenWith(completion: @escaping () -> Void) {
        guard let currentCell = collectionView.cellForItem(at: currentIndex) as? NoPreviewCollectionViewCell else { return }

        downloadQueue.observeFileDownloaded(self, fileId: currentFile.id) { [weak self] _, error in
            guard let self else { return }
            Task { @MainActor in
                if error == nil {
                    completion()
                    currentCell.observeProgress(false, file: self.currentFile)
                } else {
                    UIConstants.showSnackBarIfNeeded(error: DriveError.downloadFailed)
                }
            }
        }
        downloadQueue.addToQueue(file: currentFile, userId: accountManager.currentUserId, itemIdentifier: nil)
        currentCell.observeProgress(true, file: currentFile)
    }

    private func downloadFileIfNeeded(at indexPath: IndexPath) {
        let currentFile = previewFiles[indexPath.row]
        previewErrors.values.compactMap { $0 as? OfficePreviewError }.forEach { $0.downloadTask?.cancel() }
        currentDownloadOperation?.cancel()
        currentDownloadOperation = nil
        guard currentFile.isLocalVersionOlderThanRemote && ConvertedType.downloadableTypes.contains(currentFile.convertedType)
        else {
            return
        }

        downloadFile(at: indexPath)
    }

    private func downloadFile(at indexPath: IndexPath) {
        if let publicShareProxy = driveFileManager.publicShareProxy {
            downloadPublicShareFile(at: indexPath, publicShareProxy: publicShareProxy)
        } else {
            downloadQueue.temporaryDownload(
                file: currentFile,
                userId: accountManager.currentUserId,
                onOperationCreated: { operation in
                    self.trackOperationCreated(at: indexPath, downloadOperation: operation)
                },
                completion: { error in
                    self.downloadCompletion(at: indexPath, error: error)
                }
            )
        }
    }

    private func downloadPublicShareFile(at indexPath: IndexPath, publicShareProxy: PublicShareProxy) {
        downloadQueue.addPublicShareToQueue(
            file: currentFile,
            driveFileManager: driveFileManager,
            publicShareProxy: publicShareProxy, itemIdentifier: nil,
            onOperationCreated: { operation in
                self.trackOperationCreated(at: indexPath, downloadOperation: operation)
            }, completion: { error in
                self.downloadCompletion(at: indexPath, error: error)
            }
        )
    }

    private func trackOperationCreated(at indexPath: IndexPath, downloadOperation: DownloadAuthenticatedOperation?) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            currentDownloadOperation = downloadOperation
            if let progress = currentDownloadOperation?.progress,
               let cell = collectionView.cellForItem(at: indexPath) as? DownloadProgressObserver {
                cell.setDownloadProgress(progress)
            }
        }
    }

    private func downloadCompletion(at indexPath: IndexPath, error: DriveError?) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            self.updateFileForCurrentIndex()
            currentDownloadOperation = nil

            guard view.window != nil else { return }

            if let error {
                if error != .taskCancelled {
                    previewErrors[currentFile.id] = PreviewError(fileId: currentFile.id, underlyingError: error)
                    collectionView.reloadItems(at: [indexPath])
                }
            } else {
                (collectionView.cellForItem(at: indexPath) as? DownloadingPreviewCollectionViewCell)?
                    .previewDownloadTask?.cancel()
                previewErrors[currentFile.id] = nil
                collectionView.endEditing(true)
                collectionView.reloadItems(at: [indexPath])
                updateNavigationBar()
            }
        }
    }

    static func instantiate(
        files: [File],
        index: Int,
        driveFileManager: DriveFileManager,
        normalFolderHierarchy: Bool,
        presentationOrigin: PresentationOrigin
    ) -> PreviewViewController {
        let previewPageViewController = Storyboard.files
            .instantiateViewController(withIdentifier: "PreviewViewController") as! PreviewViewController
        previewPageViewController.previewFiles = files
        previewPageViewController.driveFileManager = driveFileManager
        previewPageViewController.normalFolderHierarchy = normalFolderHierarchy
        previewPageViewController.presentationOrigin = presentationOrigin
        // currentIndex should be set at the end of the function as the it takes time
        // and the viewDidLoad() is called before the function returns
        // this should be fixed in the future with the refactor of the init
        previewPageViewController.currentIndex = IndexPath(row: index, section: 0)
        return previewPageViewController
    }

    // MARK: - State restoration

    var currentSceneMetadata: [AnyHashable: Any] {
        let allFilesIds = previewFiles.map(\.id)
        let currentIndexRow = currentIndex.row
        guard currentIndexRow <= allFilesIds.count else {
            return [:]
        }

        return [
            SceneRestorationKeys.lastViewController.rawValue: SceneRestorationScreens.PreviewViewController.rawValue,
            SceneRestorationValues.driveId.rawValue: driveFileManager.driveId,
            SceneRestorationValues.Carousel.filesIds.rawValue: allFilesIds,
            SceneRestorationValues.Carousel.currentIndex.rawValue: currentIndexRow,
            SceneRestorationValues.Carousel.normalFolderHierarchy.rawValue: normalFolderHierarchy,
            SceneRestorationValues.Carousel.presentationOrigin.rawValue: presentationOrigin.rawValue
        ]
    }
}

// MARK: - Collection view data source

extension PreviewViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return previewFiles.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        let file = previewFiles[indexPath.row]
        if let cell = cell as? DownloadingPreviewCollectionViewCell {
            if let publicShareProxy = driveFileManager.publicShareProxy {
                cell.progressiveLoadingForPublicShareFile(file, publicShareProxy: publicShareProxy)
            } else {
                cell.progressiveLoadingForFile(file)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let file = previewFiles[indexPath.row]
        // File is already downloaded and up to date OR we can remote play it (audio / video)
        if previewErrors[file.id] == nil &&
            (!file.isLocalVersionOlderThanRemote || ConvertedType.remotePlayableTypes.contains(file.convertedType)) {
            switch file.convertedType {
            case .image:
                if let image = UIImage(contentsOfFile: file.localUrl.path) {
                    let cell = collectionView.dequeueReusableCell(type: ImagePreviewCollectionViewCell.self, for: indexPath)
                    cell.previewDelegate = self
                    cell.imagePreview.image = image
                    return cell
                } else {
                    return getNoLocalPreviewCellFor(file: file, indexPath: indexPath)
                }
            case .pdf:
                let cell = collectionView.dequeueReusableCell(type: PdfPreviewCollectionViewCell.self, for: indexPath)
                cell.previewDelegate = self
                cell.configureWith(file: file)
                return cell
            case .video:
                let cell = collectionView.dequeueReusableCell(type: VideoCollectionViewCell.self, for: indexPath)
                cell.previewDelegate = self
                cell.parentViewController = self
                cell.driveFileManager = driveFileManager
                cell.configureWith(file: file)
                return cell
            case .audio:
                let cell = collectionView.dequeueReusableCell(type: AudioCollectionViewCell.self, for: indexPath)
                cell.previewDelegate = self
                cell.driveFileManager = driveFileManager
                cell.configureWith(file: file)
                return cell
            case .spreadsheet, .presentation, .text:
                let cell = collectionView.dequeueReusableCell(type: OfficePreviewCollectionViewCell.self, for: indexPath)
                cell.previewDelegate = self
                cell.configureWith(file: file)
                let topInset = fullScreenPreview ? 0 : UIConstants.Padding.standard
                cell.setTopInset(topInset)
                return cell
            case .code:
                let cell = collectionView.dequeueReusableCell(type: CodePreviewCollectionViewCell.self, for: indexPath)
                cell.previewDelegate = self
                cell.configure(with: file)
                let topInset = fullScreenPreview ? 0 : UIConstants.Padding.standard
                cell.setTopInset(topInset)
                return cell
            default:
                return getNoLocalPreviewCellFor(file: file, indexPath: indexPath)
            }
        } else {
            return getNoLocalPreviewCellFor(file: file, indexPath: indexPath)
        }
    }

    private func getNoLocalPreviewCellFor(file: File, indexPath: IndexPath) -> UICollectionViewCell {
        if let officePreviewError = previewErrors[file.id] as? OfficePreviewError {
            if let url = officePreviewError.pdfUrl {
                let cell = collectionView.dequeueReusableCell(type: PdfPreviewCollectionViewCell.self, for: indexPath)
                cell.previewDelegate = self
                cell.configureWith(documentUrl: url)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(type: NoPreviewCollectionViewCell.self, for: indexPath)
                cell.configureWith(file: file)
                if let progress = officePreviewError.pdfGenerationProgress {
                    cell.setDownloadProgress(progress)
                } else if officePreviewError.underlyingError != nil {
                    cell.errorDownloading()
                }
                cell.previewDelegate = self
                return cell
            }
        } else if let previewError = previewErrors[file.id], let avError = previewError.underlyingError as? AVError {
            let errorMessage = avError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
                ?? KDriveResourcesStrings.Localizable.errorGeneric
            let cell = collectionView.dequeueReusableCell(type: NoPreviewCollectionViewCell.self, for: indexPath)
            cell.configureWith(file: file, errorReason: errorMessage)
            cell.previewDelegate = self
            return cell
        } else if file.supportedBy.contains(.thumbnail) && !ConvertedType.ignoreThumbnailTypes.contains(file.convertedType) {
            let cell = collectionView.dequeueReusableCell(type: DownloadingPreviewCollectionViewCell.self, for: indexPath)
            if let downloadOperation = currentDownloadOperation,
               let progress = downloadOperation.progress,
               downloadOperation.fileId == file.id {
                cell.setDownloadProgress(progress)
            }
            cell.previewDelegate = self
            return cell
        } else if ReachabilityListener.instance.currentStatus == .offline {
            let cell = collectionView.dequeueReusableCell(type: NoPreviewCollectionViewCell.self, for: indexPath)
            cell.configureWith(file: file, isOffline: true)
            cell.previewDelegate = self
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(type: NoPreviewCollectionViewCell.self, for: indexPath)
            cell.configureWith(file: file)
            if let downloadOperation = currentDownloadOperation,
               let progress = downloadOperation.progress,
               downloadOperation.fileId == file.id {
                cell.setDownloadProgress(progress)
            }
            cell.previewDelegate = self
            return cell
        }
    }
}

// MARK: - Collection view delegate

extension PreviewViewController: UICollectionViewDelegate {}

// MARK: - Floating Panel Controller Delegate

extension PreviewViewController: FloatingPanelControllerDelegate {
    func floatingPanelShouldBeginDragging(_ vc: FloatingPanelController) -> Bool {
        return presentationOrigin != .activities
    }
}

// MARK: - Document interaction controller delegate

extension PreviewViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionController(
        _ controller: UIDocumentInteractionController,
        willBeginSendingToApplication application: String?
    ) {
        // Dismiss interaction controller when the user taps an app
        controller.dismissMenu(animated: true)
    }

    func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        hideFloatingPanel(false)
    }
}
