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
import InfomaniakCoreUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import PhotosUI
import UIKit

class SaveFileViewController: UIViewController {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var fileImportHelper: FileImportHelper
    @LazyInjectService var appContextService: AppContextServiceable

    enum SaveFileSection {
        case alert
        case fileName
        case fileType
        case driveSelection
        case directorySelection
        case photoFormatOption
        case importing
    }

    var lastSelectedDirectory: File? {
        guard UserDefaults.shared.lastSelectedDrive == selectedDriveFileManager?.drive.id else { return nil }
        return selectedDriveFileManager?.getCachedFile(id: UserDefaults.shared.lastSelectedDirectory)
    }

    var sections: [SaveFileSection] = [.fileName, .driveSelection, .directorySelection]

    private var originalDriveId: Int = {
        @InjectService var accountManager: AccountManageable
        return accountManager.currentDriveId
    }()

    private var originalUserId: Int = {
        @InjectService var accountManager: AccountManageable
        return accountManager.currentUserId
    }()

    var selectedDriveFileManager: DriveFileManager?
    var selectedDirectory: File?
    var photoFormat = PhotoFileFormat.jpg
    var itemProviders: [NSItemProvider]? {
        didSet {
            setItemProviders()
        }
    }

    var assetIdentifiers: [String]? {
        didSet {
            setAssetIdentifiers()
        }
    }

    var items = [ImportedFile]()
    var userPreferredPhotoFormat = UserDefaults.shared.importPhotoFormat {
        didSet {
            UserDefaults.shared.importPhotoFormat = userPreferredPhotoFormat
        }
    }

    var itemProvidersContainHeicPhotos: Bool {
        if let itemProviders, !itemProviders.isEmpty {
            return itemProviders.contains {
                $0.hasItemConformingToTypeIdentifier(UTI.heic.identifier)
                    && $0.hasItemConformingToTypeIdentifier(UTI.jpeg.identifier)
            }
        }
        if let assetIdentifiers, !assetIdentifiers.isEmpty {
            return PHAsset.containsPhotosAvailableInHEIC(assetIdentifiers: assetIdentifiers)
        }
        return false
    }

    private var errorCount = 0
    private var importProgress: Progress?
    private var enableButton = false {
        didSet {
            guard let footer = tableView.footerView(forSection: tableView.numberOfSections - 1) as? FooterButtonView else {
                return
            }
            footer.footerButton.isEnabled = enableButton
        }
    }

    private var importInProgress: Bool {
        if let progress = importProgress {
            return progress.fractionCompleted < 1
        } else {
            return false
        }
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var closeBarButtonItem: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set selected drive and directory to last values
        if selectedDirectory == nil {
            if selectedDriveFileManager == nil, let driveFileManager = accountManager.getDriveFileManager(
                for: UserDefaults.shared.lastSelectedDrive,
                userId: UserDefaults.shared.lastSelectedUser
            ) {
                selectedDriveFileManager = driveFileManager
            }
            selectedDirectory = lastSelectedDirectory?.driveId == selectedDriveFileManager?.drive.id
                ? lastSelectedDirectory
                : selectedDriveFileManager?.getCachedRootFile()
        }

        closeBarButtonItem.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
        navigationItem.backButtonTitle = KDriveResourcesStrings.Localizable.saveExternalFileTitle
        navigationItem.hideBackButtonText()

        tableView.separatorColor = .clear
        tableView.register(cellView: AlertTableViewCell.self)
        tableView.register(cellView: UploadTableViewCell.self)
        tableView.register(cellView: FileNameTableViewCell.self)
        tableView.register(cellView: ImportingTableViewCell.self)
        tableView.register(cellView: LocationTableViewCell.self)
        tableView.register(cellView: PhotoFormatTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listFloatingButtonPaddingBottom, right: 0)
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 50
        hideKeyboardWhenTappedAround()
        updateButton()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.save.displayName, "SaveFile"])
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset.bottom = keyboardSize.height

            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        tableView.contentInset.bottom = 0
        UIView.animate(withDuration: 0.1) {
            self.view.layoutIfNeeded()
        }
    }

    func dismiss(animated: Bool, clean: Bool = true, completion: (() -> Void)? = nil) {
        Task {
            // Cleanup file that were duplicated to appGroup on extension mode
            if appContextService.isExtension && clean {
                await items.concurrentForEach { item in
                    try? FileManager.default.removeItem(at: item.path)
                }
            }

            navigationController?.dismiss(animated: animated, completion: completion)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func setAssetIdentifiers() {
        guard let assetIdentifiers else { return }
        sections = [.importing]
        importProgress = fileImportHelper.importAssets(
            assetIdentifiers,
            userPreferredPhotoFormat: userPreferredPhotoFormat
        ) { [weak self] importedFiles, errorCount in
            guard let self else {
                return
            }

            items = importedFiles
            self.errorCount = errorCount
            Task { @MainActor in
                self.updateTableViewAfterImport()
            }
        }
    }

    private func setItemProviders() {
        guard let itemProviders else { return }
        sections = [.importing]
        importProgress = fileImportHelper
            .importItems(itemProviders,
                         userPreferredPhotoFormat: userPreferredPhotoFormat) { [weak self] importedFiles, errorCount in
                guard let self else {
                    return
                }

                items = importedFiles
                self.errorCount = errorCount
                Task { @MainActor in
                    self.updateTableViewAfterImport()
                }
            }
    }

    private func updateButton() {
        enableButton = selectedDirectory != nil && items.allSatisfy { !$0.name.isEmpty } && !items.isEmpty && !importInProgress
    }

    private func updateTableViewAfterImport() {
        guard !importInProgress else { return }
        // Update table view
        var newSections = [SaveFileSection]()
        if errorCount > 0 {
            newSections.append(.alert)
        }
        if !items.isEmpty {
            #if ISEXTENSION
            if selectedDriveFileManager == nil {
                newSections.append(contentsOf: [.fileName, .driveSelection])
            } else {
                newSections.append(contentsOf: [.fileName, .driveSelection, .directorySelection])
            }
            #else
            newSections.append(contentsOf: [.fileName, .directorySelection])
            #endif

            if itemProvidersContainHeicPhotos {
                newSections.append(.photoFormatOption)
            }
        }
        sections = newSections
        // Reload data if needed
        if isViewLoaded {
            updateButton()
            tableView.reloadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setInfomaniakAppearanceNavigationBar()
        tableView.reloadData()
    }

    class func instantiate(driveFileManager: DriveFileManager?) -> SaveFileViewController {
        let viewController = Storyboard.saveFile
            .instantiateViewController(withIdentifier: "SaveFileViewController") as! SaveFileViewController
        viewController.selectedDriveFileManager = driveFileManager
        return viewController
    }

    class func instantiateInNavigationController(driveFileManager: DriveFileManager?,
                                                 file: ImportedFile? = nil) -> TitleSizeAdjustingNavigationController {
        let saveViewController = instantiate(driveFileManager: driveFileManager)
        if let file {
            saveViewController.items = [file]
        }
        let navigationController = TitleSizeAdjustingNavigationController(rootViewController: saveViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    @IBAction func close(_ sender: Any) {
        importProgress?.cancel()
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SaveFileViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = sections[section]
        if section == .fileName {
            return items.count
        } else {
            return 1
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .alert:
            let cell = tableView.dequeueReusableCell(type: AlertTableViewCell.self, for: indexPath)
            cell.configure(with: .warning, message: KDriveResourcesStrings.Localizable.snackBarUploadError(errorCount))
            return cell
        case .fileName:
            let item = items[indexPath.row]
            if items.count > 1 {
                let cell = tableView.dequeueReusableCell(type: UploadTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(
                    isFirst: indexPath.row == 0,
                    isLast: indexPath.row == self.tableView(tableView, numberOfRowsInSection: indexPath.section) - 1
                )
                cell.configureWith(importedFile: item)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(type: FileNameTableViewCell.self, for: indexPath)
                cell.textField.text = item.name
                cell.textDidChange = { [weak self] text in
                    guard let self else { return }
                    item.name = text ?? KDriveResourcesStrings.Localizable.allUntitledFileName
                    if let text, !text.isEmpty {
                        updateButton()
                    } else {
                        enableButton = false
                    }
                }
                return cell
            }
        case .driveSelection:
            let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.configure(with: selectedDriveFileManager?.drive)
            return cell
        case .directorySelection:
            let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.configure(with: selectedDirectory, drive: selectedDriveFileManager!.drive)
            return cell
        case .photoFormatOption:
            let cell = tableView.dequeueReusableCell(type: PhotoFormatTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.configure(with: userPreferredPhotoFormat)
            return cell
        case .importing:
            let cell = tableView.dequeueReusableCell(type: ImportingTableViewCell.self, for: indexPath)
            cell.importationProgressView.observedProgress = importProgress
            return cell
        default:
            fatalError("Not supported by this datasource")
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .fileName:
            return HomeTitleView.instantiate(title: "")
        case .driveSelection:
            return HomeTitleView.instantiate(title: "kDrive")
        case .directorySelection:
            return HomeTitleView.instantiate(title: KDriveResourcesStrings.Localizable.allPathTitle)
        case .photoFormatOption:
            return HomeTitleView.instantiate(title: KDriveResourcesStrings.Localizable.photoFormatTitle)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == tableView.numberOfSections - 1 && !importInProgress {
            return 124
        }
        return 32
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableView.numberOfSections - 1 && !importInProgress {
            let view = FooterButtonView.instantiate(title: KDriveResourcesStrings.Localizable.buttonSave)
            view.delegate = self
            view.footerButton.isEnabled = enableButton
            return view
        }
        return nil
    }
}

// MARK: - UITableViewDelegate

extension SaveFileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .fileName:
            let item = items[indexPath.row]
            if items.count > 1 {
                let alert = AlertFieldViewController(
                    title: KDriveResourcesStrings.Localizable.buttonRename,
                    placeholder: KDriveResourcesStrings.Localizable.hintInputFileName,
                    text: item.name,
                    action: KDriveResourcesStrings.Localizable.buttonSave,
                    loading: false
                ) { newName in
                    item.name = newName
                    tableView.reloadRows(at: [indexPath], with: .automatic)
                }
                alert.textFieldConfiguration = .fileNameConfiguration
                alert.textFieldConfiguration.selectedRange = item.name
                    .startIndex ..< (item.name.lastIndex(where: { $0 == "." }) ?? item.name.endIndex)
                present(alert, animated: true)
            }
        case .driveSelection:
            let selectDriveViewController = SelectDriveViewController.instantiate()
            selectDriveViewController.selectedDrive = selectedDriveFileManager?.drive
            selectDriveViewController.delegate = self
            navigationController?.pushViewController(selectDriveViewController, animated: true)
        case .directorySelection:
            guard let driveFileManager = selectedDriveFileManager else { return }
            let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(
                driveFileManager: driveFileManager,
                startDirectory: selectedDirectory,
                delegate: self
            )
            present(selectFolderNavigationController, animated: true)
        case .photoFormatOption:
            let selectPhotoFormatViewController = SelectPhotoFormatViewController
                .instantiate(selectedFormat: userPreferredPhotoFormat)
            selectPhotoFormatViewController.delegate = self
            navigationController?.pushViewController(selectPhotoFormatViewController, animated: true)
        default:
            break
        }
    }
}

// MARK: - SelectFolderDelegate

extension SaveFileViewController: SelectFolderDelegate {
    func didSelectFolder(_ folder: File) {
        if folder.id == DriveFileManager.constants.rootID {
            selectedDirectory = selectedDriveFileManager?.getCachedRootFile()
        } else {
            selectedDirectory = folder
        }
        updateButton()
        tableView.reloadData()
    }
}

// MARK: - SelectDriveDelegate

extension SaveFileViewController: SelectDriveDelegate {
    func didSelectDrive(_ drive: Drive) {
        if let selectedDriveFileManager = accountManager.getDriveFileManager(for: drive.id, userId: drive.userId) {
            self.selectedDriveFileManager = selectedDriveFileManager
            selectedDirectory = selectedDriveFileManager.getCachedRootFile()
            sections = [.fileName, .driveSelection, .directorySelection]
            if itemProvidersContainHeicPhotos {
                sections.append(.photoFormatOption)
            }
        }
        updateButton()
    }
}

// MARK: - SelectPhotoFormatDelegate

extension SaveFileViewController: SelectPhotoFormatDelegate {
    func didSelectPhotoFormat(_ format: PhotoFileFormat) {
        if userPreferredPhotoFormat != format {
            userPreferredPhotoFormat = format
            if itemProviders?.isEmpty == false {
                setItemProviders()
            } else {
                setAssetIdentifiers()
            }
        }
    }
}
