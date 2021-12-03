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

import FloatingPanel
import InfomaniakCore
import kDriveCore
import kDriveResources
import PDFKit
import Sentry
import UIKit

protocol PreviewContentCellDelegate: AnyObject {
    func updateNavigationBar()
    func setFullscreen(_ fullscreen: Bool?)
    func errorWhilePreviewing(fileId: Int, error: Error)
}

class PreviewViewController: UIViewController, PreviewContentCellDelegate {
    @IBOutlet weak var collectionView: UICollectionView!
    private var previewFiles = [File]()
    private var previewErrorFileIds = Set<Int>()
    private var driveFileManager: DriveFileManager!
    private var normalFolderHierarchy = true
    private var initialLoading = true
    private var fromActivities = false
    private var centerIndexPathBeforeRotate: IndexPath?
    private var currentIndex = IndexPath(row: 0, section: 0)
    private var currentDownloadOperation: DownloadOperation?
    private let pdfPageLabel = UILabel(frame: .zero)
    private var titleWidthConstraint: NSLayoutConstraint?
    private var titleHeightConstraint: NSLayoutConstraint?
    private let editButton = UIButton(type: .custom)
    private let backButton = UIButton(type: .custom)
    private var popRecognizer: InteractivePopRecognizer?
    @IBOutlet weak var statusBarView: UIView!
    private var fullScreenPreview = false
    private var heightToHide = CGFloat(0)

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

        collectionView.register(cellView: NoPreviewCollectionViewCell.self)
        collectionView.register(cellView: DownloadingPreviewCollectionViewCell.self)
        collectionView.register(cellView: ImagePreviewCollectionViewCell.self)
        collectionView.register(cellView: PdfPreviewCollectionViewCell.self)
        collectionView.register(cellView: VideoCollectionViewCell.self)
        collectionView.register(cellView: OfficePreviewCollectionViewCell.self)
        collectionView.register(cellView: AudioCollectionViewCell.self)
        collectionView.contentInsetAdjustmentBehavior = .never

        floatingPanelViewController = DriveFloatingPanelController()
        floatingPanelViewController.isRemovalInteractionEnabled = false
        fileInformationsViewController = FileActionsFloatingPanelViewController()
        fileInformationsViewController.presentingParent = self
        fileInformationsViewController.normalFolderHierarchy = normalFolderHierarchy
        floatingPanelViewController.set(contentViewController: fileInformationsViewController)
        floatingPanelViewController.track(scrollView: fileInformationsViewController.collectionView)
        floatingPanelViewController.delegate = self

        if fromActivities {
            floatingPanelViewController.surfaceView.grabberHandle.isHidden = true
        }

        pdfPageLabel.font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .medium)
        pdfPageLabel.textColor = .white
        pdfPageLabel.textAlignment = .center
        pdfPageLabel.contentMode = .center
        pdfPageLabel.numberOfLines = 1
        pdfPageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pdfPageLabel)

        editButton.tintColor = .white
        editButton.backgroundColor = KDriveResourcesAsset.previewBackgroundColor.color.withAlphaComponent(0.4)
        editButton.contentMode = .center
        editButton.setImage(KDriveResourcesAsset.editDocument.image, for: .normal)
        editButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        editButton.imageEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        editButton.cornerRadius = editButton.frame.width / 2
        editButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonEdit
        editButton.addTarget(self, action: #selector(editFile), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editButton)

        backButton.tintColor = .white
        backButton.backgroundColor = KDriveResourcesAsset.previewBackgroundColor.color.withAlphaComponent(0.4)
        backButton.contentMode = .center
        backButton.setImage(KDriveResourcesAsset.chevronLeft.image, for: .normal)
        backButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        backButton.imageEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        backButton.cornerRadius = backButton.frame.width / 2
        backButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonBack
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)

        // Constraints
        titleWidthConstraint = pdfPageLabel.widthAnchor.constraint(equalToConstant: pdfPageLabel.frame.width)
        titleWidthConstraint?.isActive = true
        titleHeightConstraint = pdfPageLabel.heightAnchor.constraint(equalToConstant: pdfPageLabel.frame.height)
        titleHeightConstraint?.isActive = true
        let constraints = [
            backButton.widthAnchor.constraint(equalToConstant: 50),
            backButton.heightAnchor.constraint(equalToConstant: 50),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            editButton.widthAnchor.constraint(equalToConstant: 50),
            editButton.heightAnchor.constraint(equalToConstant: 50),
            editButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            editButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            pdfPageLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            pdfPageLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            pdfPageLabel.centerYAnchor.constraint(equalTo: editButton.centerYAnchor)
        ]
        NSLayoutConstraint.activate(constraints)

        observeFileUpdated()
    }

    @objc func tapPreview() {
        setFullscreen()
    }

    func observeFileUpdated() {
        driveFileManager?.observeFileUpdated(self, fileId: nil) { [weak self] file in
            if self?.currentFile.id == file.id {
                self?.currentFile = file
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.collectionView.endEditing(true)
                    self.collectionView.reloadItems(at: [self.currentIndex])
                }
            }
        }
    }

    private func setInteractiveRecognizer() {
        guard let controller = navigationController else { return }
        popRecognizer = InteractivePopRecognizer(controller: controller)
        controller.interactivePopGestureRecognizer?.delegate = popRecognizer
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        if initialLoading {
            collectionView.setNeedsLayout()
            collectionView.layoutIfNeeded()

            updateFileForCurrentIndex()

            collectionView.scrollToItem(at: currentIndex, at: .centeredVertically, animated: false)
            updateNavigationBar()
            downloadFileIfNeeded(at: currentIndex)
            initialLoading = false
        }
        setInteractiveRecognizer()
    }

    private func updateFileForCurrentIndex() {
        fileInformationsViewController.setFile(currentFile, driveFileManager: driveFileManager)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        present(floatingPanelViewController, animated: true, completion: nil)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        becomeFirstResponder()

        heightToHide = backButton.frame.minY
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        let currentCell = (collectionView.cellForItem(at: currentIndex) as? PreviewCollectionViewCell)
        currentCell?.didEndDisplaying()
        currentDownloadOperation?.cancel()
        navigationController?.interactivePopGestureRecognizer?.delegate = nil

        UIApplication.shared.endReceivingRemoteControlEvents()
        resignFirstResponder()
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            floatingPanelViewController?.dismiss(animated: false)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        centerIndexPathBeforeRotate = currentIndex
        coordinator.animate { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        } completion: { _ in
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

    var isViewDidLayoutCallFirstTime = true

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Safe areas are set here
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

    func updateNavigationBar() {
        if !currentFile.isLocalVersionOlderThanRemote() {
            switch currentFile.convertedType {
            case .pdf:
                if let pdfCell = (collectionView.cellForItem(at: currentIndex) as? PdfPreviewCollectionViewCell),
                   let currentPage = pdfCell.pdfPreview.currentPage?.pageRef?.pageNumber,
                   let totalPages = pdfCell.pdfPreview.document?.pageCount {
                    setNavbarForPdf(currentPage: currentPage, totalPages: totalPages)
                } else {
                    setNavbarStandard()
                }
            case .text, .presentation, .spreadsheet:
                if currentFile.rights?.write ?? false {
                    setNavbarForEditing()
                } else {
                    setNavbarStandard()
                }
            default:
                setNavbarStandard()
            }
        } else {
            setNavbarStandard()
        }
    }

    private func setNavbarStandard() {
        backButton.isHidden = false
        pdfPageLabel.isHidden = true
        editButton.isHidden = true
    }

    private func setNavbarForEditing() {
        backButton.isHidden = false
        pdfPageLabel.isHidden = true
        editButton.isHidden = false
    }

    private func setNavbarForPdf(currentPage: Int, totalPages: Int) {
        backButton.isHidden = false
        editButton.isHidden = true
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
        floatingPanelViewController.dismiss(animated: true)
        OnlyOfficeViewController.open(driveFileManager: driveFileManager, file: currentFile, viewController: self)
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
            let hideStatusBar = CGAffineTransform(translationX: 0, y: self.fullScreenPreview ? -self.statusBarView.frame.height : 0)
            self.statusBarView.transform = hideStatusBar
        }
        UIView.animate(withDuration: 0.4) {
            let hideButton = CGAffineTransform(translationX: 0, y: self.fullScreenPreview ? -(self.backButton.frame.height + self.heightToHide) : 0)
            self.backButton.transform = hideButton
            self.pdfPageLabel.transform = hideButton
            self.editButton.transform = hideButton
        }
        floatingPanelViewController.move(to: fullScreenPreview ? .hidden : .tip, animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let centerCellIndexPath = collectionView.indexPathForItem(at: view.convert(view.center, to: collectionView)),
           currentIndex != centerCellIndexPath {
            let previousCell = (collectionView.cellForItem(at: currentIndex) as? PreviewCollectionViewCell)
            previousCell?.didEndDisplaying()

            currentIndex = centerCellIndexPath
            updateFileForCurrentIndex()

            updateNavigationBar()
            downloadFileIfNeeded(at: currentIndex)
        }
    }

    func errorWhilePreviewing(fileId: Int, error: Error) {
        previewErrorFileIds.insert(fileId)
        if let index = previewFiles.firstIndex(where: { $0.id == fileId }) {
            collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        }
    }

    private func downloadFileIfNeeded(at indexPath: IndexPath) {
        let currentFile = previewFiles[indexPath.row]
        currentDownloadOperation?.cancel()
        currentDownloadOperation = nil
        if currentFile.isLocalVersionOlderThanRemote() && ConvertedType.downloadableTypes.contains(currentFile.convertedType) {
            DownloadQueue.instance.temporaryDownload(
                file: currentFile,
                onOperationCreated: { operation in
                    DispatchQueue.main.async { [weak self] in
                        self?.currentDownloadOperation = operation
                        if let progress = self?.currentDownloadOperation?.task?.progress,
                           let cell = self?.collectionView.cellForItem(at: indexPath) as? DownloadProgressObserver {
                            cell.setDownloadProgress(progress)
                        }
                    }
                },
                completion: { error in
                    DispatchQueue.main.async { [weak self] in
                        if self?.view.window != nil {
                            if let error = error {
                                if error != .taskCancelled {
                                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorDownload)
                                    if let cell = (self?.collectionView.cellForItem(at: indexPath) as? NoPreviewCollectionViewCell) {
                                        cell.errorDownloading()
                                    }
                                }
                            } else {
                                (self?.collectionView.cellForItem(at: indexPath) as? DownloadingPreviewCollectionViewCell)?.previewDownloadTask?.cancel()
                                self?.collectionView.endEditing(true)
                                self?.collectionView.reloadItems(at: [indexPath])
                                self?.updateNavigationBar()
                            }
                        }
                    }
                }
            )
        }
    }

    class func instantiate(files: [File], index: Int, driveFileManager: DriveFileManager, normalFolderHierarchy: Bool, fromActivities: Bool) -> PreviewViewController {
        let previewPageViewController = Storyboard.files.instantiateViewController(withIdentifier: "PreviewViewController") as! PreviewViewController
        previewPageViewController.previewFiles = files
        previewPageViewController.driveFileManager = driveFileManager
        previewPageViewController.currentIndex = IndexPath(row: index, section: 0)
        previewPageViewController.normalFolderHierarchy = normalFolderHierarchy
        previewPageViewController.fromActivities = fromActivities
        return previewPageViewController
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
        coder.encode(previewFiles.map(\.id), forKey: "Files")
        coder.encode(currentIndex.row, forKey: "CurrentIndex")
        coder.encode(initialLoading, forKey: "InitialLoading")
        coder.encode(normalFolderHierarchy, forKey: "NormalFolderHierarchy")
        coder.encode(fromActivities, forKey: "FromActivities")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        initialLoading = coder.decodeBool(forKey: "InitialLoading")
        normalFolderHierarchy = coder.decodeBool(forKey: "NormalFolderHierarchy")
        fileInformationsViewController.normalFolderHierarchy = normalFolderHierarchy
        fromActivities = coder.decodeBool(forKey: "FromActivities")
        if fromActivities {
            floatingPanelViewController.surfaceView.grabberHandle.isHidden = true
        }
        guard let driveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId) else {
            navigationController?.popViewController(animated: true)
            return
        }
        self.driveFileManager = driveFileManager
        let previewFileIds = coder.decodeObject(forKey: "Files") as? [Int] ?? []
        let realm = driveFileManager.getRealm()
        previewFiles = previewFileIds.compactMap { driveFileManager.getCachedFile(id: $0, using: realm) }
        currentIndex = IndexPath(row: coder.decodeInteger(forKey: "CurrentIndex"), section: 0)
        if currentIndex.row >= previewFiles.count {
            navigationController?.popViewController(animated: true)
            return
        }
        // Update UI
        DispatchQueue.main.async { [self] in
            collectionView.reloadData()
            updateFileForCurrentIndex()
            collectionView.scrollToItem(at: currentIndex, at: .centeredVertically, animated: false)
            updateNavigationBar()
            downloadFileIfNeeded(at: currentIndex)
        }
        observeFileUpdated()
    }
}

// MARK: - Collection view data source

extension PreviewViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return previewFiles.count
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let file = previewFiles[indexPath.row]
        if let cell = cell as? DownloadingPreviewCollectionViewCell {
            cell.progressiveLoadingForFile(file)
        } else if let cell = cell as? AudioCollectionViewCell {
            cell.setUpObservers()
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let file = previewFiles[indexPath.row]
        // File is already downloaded and up to date OR we can remote play it (audio / video)
        if !previewErrorFileIds.contains(file.id) && (!file.isLocalVersionOlderThanRemote() || ConvertedType.remotePlayableTypes.contains(file.convertedType)) {
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
                cell.parentViewController = floatingPanelViewController
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
                return cell
            default:
                return getNoLocalPreviewCellFor(file: file, indexPath: indexPath)
            }
        } else {
            return getNoLocalPreviewCellFor(file: file, indexPath: indexPath)
        }
    }

    private func getNoLocalPreviewCellFor(file: File, indexPath: IndexPath) -> UICollectionViewCell {
        if previewErrorFileIds.contains(file.id) {
            let cell = collectionView.dequeueReusableCell(type: NoPreviewCollectionViewCell.self, for: indexPath)
            cell.configureWith(file: file)
            cell.previewDelegate = self
            return cell
        } else if file.hasThumbnail && !ConvertedType.ignoreThumbnailTypes.contains(file.convertedType) {
            let cell = collectionView.dequeueReusableCell(type: DownloadingPreviewCollectionViewCell.self, for: indexPath)
            cell.parentViewController = self
            if let downloadOperation = currentDownloadOperation,
               let progress = downloadOperation.task?.progress,
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
               let progress = downloadOperation.task?.progress,
               downloadOperation.fileId == file.id {
                cell.setDownloadProgress(progress)
            }
            cell.previewDelegate = self
            return cell
        }
    }
}

// MARK: - Collection view delegate flow layout

extension PreviewViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }

    func collectionView(_ collectionView: UICollectionView, targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        guard let oldCenter = centerIndexPathBeforeRotate else {
            return proposedContentOffset
        }

        let attrs = collectionView.layoutAttributesForItem(at: oldCenter)

        let newOriginForOldIndex = attrs?.frame.origin

        return newOriginForOldIndex ?? proposedContentOffset
    }
}

// MARK: - Collection view delegate

extension PreviewViewController: UICollectionViewDelegate {}

// MARK: - Floating Panel Controller Delegate

extension PreviewViewController: FloatingPanelControllerDelegate {
    func floatingPanelShouldBeginDragging(_ vc: FloatingPanelController) -> Bool {
        return !fromActivities
    }
}
