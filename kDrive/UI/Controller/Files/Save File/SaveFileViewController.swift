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

import InfomaniakCore
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import PhotosUI
import UIKit

class SaveFileViewController: UIViewController {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var fileImportHelper: FileImportHelper
    @LazyInjectService var appContextService: AppContextServiceable

    private var originalDriveId: Int = {
        @InjectService var accountManager: AccountManageable
        return accountManager.currentDriveId
    }()

    private var originalUserId: Int = {
        @InjectService var accountManager: AccountManageable
        return accountManager.currentUserId
    }()

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

    var publicShareExceptIds = [Int]()
    var publicShareFileIds = [Int]()
    var publicShareProxy: PublicShareProxy?
    var isPublicShareFiles: Bool {
        publicShareProxy != nil
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

    var errorCount = 0
    var importProgress: Progress?
    var enableButton = false {
        didSet {
            guard let footer = tableView.footerView(forSection: tableView.numberOfSections - 1) as? FooterButtonView else {
                return
            }
            footer.footerButton.isEnabled = enableButton
        }
    }

    var importInProgress: Bool {
        if let progress = importProgress {
            return progress.fractionCompleted < 1
        } else {
            return false
        }
    }

    @MainActor var onDismissViewController: (() -> Void)?
    @MainActor var onSave: (() -> Void)?

    @IBOutlet var tableView: UITableView!
    @IBOutlet var closeBarButtonItem: UIBarButtonItem!

    // MARK: View lifecycle

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
            selectedDirectory = getBestDirectory()
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
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.List.floatingButtonPaddingBottom, right: 0)
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setInfomaniakAppearanceNavigationBar()
        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.save.displayName, "SaveFile"])
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: Objc

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

    @IBAction func close(_ sender: Any) {
        importProgress?.cancel()
        dismiss(animated: true)
        if let extensionContext {
            extensionContext.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    // MARK: Helpers

    func getBestDirectory() -> File? {
        if lastSelectedDirectory?.driveId == selectedDriveFileManager?.drive.id {
            return lastSelectedDirectory
        }

        guard let selectedDriveFileManager else { return nil }

        let myFilesDirectory = selectedDriveFileManager.database.fetchResults(ofType: File.self) { lazyFiles in
            lazyFiles.filter("rawVisibility = %@", FileVisibility.isPrivateSpace.rawValue)
        }.first

        if let myFilesDirectory {
            return myFilesDirectory.freezeIfNeeded()
        }

        // If we are in a shared with me, we only have access to some folders that are shared with the user
        guard selectedDriveFileManager.drive.sharedWithMe else { return nil }

        let firstAvailableSharedDriveDirectory = selectedDriveFileManager.database.fetchResults(ofType: File.self) { lazyFiles in
            lazyFiles.filter(
                "rawVisibility = %@ AND driveId == %d",
                FileVisibility.isInSharedSpace.rawValue,
                selectedDriveFileManager.drive.id
            )
        }.first
        return firstAvailableSharedDriveDirectory?.freezeIfNeeded()
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

    func setAssetIdentifiers() {
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

    func setItemProviders() {
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

    func updateButton() {
        guard selectedDirectory != nil, !importInProgress else {
            enableButton = false
            return
        }

        guard !isPublicShareFiles else {
            enableButton = true
            return
        }

        guard !items.isEmpty,
              items.allSatisfy({ !$0.name.isEmpty }) else {
            enableButton = false
            return
        }
        enableButton = true
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

    // MARK: Class methods

    class func instantiate(driveFileManager: DriveFileManager?) -> SaveFileViewController {
        let viewController = Storyboard.saveFile
            .instantiateViewController(withIdentifier: "SaveFileViewController") as! SaveFileViewController
        viewController.selectedDriveFileManager = driveFileManager
        return viewController
    }

    class func instantiateInNavigationController(driveFileManager: DriveFileManager,
                                                 publicShareProxy: PublicShareProxy,
                                                 publicShareFileIds: [Int],
                                                 publicShareExceptIds: [Int],
                                                 onSave: (() -> Void)?,
                                                 onDismissViewController: (() -> Void)?)
        -> TitleSizeAdjustingNavigationController {
        let saveViewController = instantiate(driveFileManager: driveFileManager)

        saveViewController.publicShareFileIds = publicShareFileIds
        saveViewController.publicShareExceptIds = publicShareExceptIds
        saveViewController.publicShareProxy = publicShareProxy
        saveViewController.onSave = onSave
        saveViewController.onDismissViewController = onDismissViewController

        return wrapInNavigationController(saveViewController)
    }

    class func instantiateInNavigationController(driveFileManager: DriveFileManager?,
                                                 files: [ImportedFile]? = nil) -> TitleSizeAdjustingNavigationController {
        let saveViewController = instantiate(driveFileManager: driveFileManager)
        if let files {
            saveViewController.items = files
        }

        return wrapInNavigationController(saveViewController)
    }

    private class func wrapInNavigationController(_ viewController: UIViewController) -> TitleSizeAdjustingNavigationController {
        let navigationController = TitleSizeAdjustingNavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }
}
