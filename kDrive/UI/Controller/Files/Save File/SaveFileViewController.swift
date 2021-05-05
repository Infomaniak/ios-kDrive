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
import PhotosUI
import InfomaniakCore
import kDriveCore
import CocoaLumberjackSwift

class SaveFileViewController: UIViewController {

    let JPEG_QUALITY: CGFloat = 0.8

    class ImportedFile {
        var name: String
        var path: URL
        var uti: UTI
        internal init(name: String, path: URL, uti: UTI) {
            self.name = name
            self.path = path
            self.uti = uti
        }
    }

    enum SaveFileSection {
        case fileName
        case fileType
        case driveSelection
        case directorySelection
        case importing
    }
    var sections: [SaveFileSection] = [.fileName, .driveSelection, .directorySelection]

    private var originalDriveId = AccountManager.instance.currentDriveId
    private var originalUserId = AccountManager.instance.currentUserId
    var selectedDriveFileManager: DriveFileManager = AccountManager.instance.currentDriveFileManager
    var selectedDirectory: File?
    var items = [ImportedFile]()
    var skipOptionsSelection = false
    private var importProgress: Progress?
    private var progressObserver: NSKeyValueObservation?
    private var enableButton: Bool = false {
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
            if let drive = DriveInfosManager.instance.getDrive(id: UserDefaults.shared.lastSelectedDrive, userId: AccountManager.instance.currentUserId),
                let driveFileManager = AccountManager.instance.getDriveFileManager(for: drive) {
                selectedDriveFileManager = driveFileManager
            }
            selectedDirectory = selectedDriveFileManager.getCachedFile(id: UserDefaults.shared.lastSelectedDirectory)
        }

        closeBarButtonItem.accessibilityLabel = KDriveStrings.Localizable.buttonClose

        tableView.separatorColor = .clear
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listFloatingButtonPaddingBottom, right: 0)
        tableView.register(cellView: MenuTableViewCell.self)
        tableView.register(cellView: FileNameTableViewCell.self)
        tableView.register(cellView: ImportingTableViewCell.self)
        tableView.register(cellView: LocationTableViewCell.self)
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 50
        hideKeyboardWhenTappedAround()
        updateButton()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        // Immediately start import if we want to skip options and import is finished
        if !importInProgress && skipOptionsSelection {
            didClickOnButton()
        }
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

    deinit {
        progressObserver?.invalidate()
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    public static func getDefaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmssSS"
        return formatter.string(from: Date())
    }

    func save(data: Data, name: String, uti: UTI) {
        let url = DriveFileManager.constants.importDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
        do {
            try data.write(to: url)
            items.append(ImportedFile(name: name, path: url, uti: uti))
        } catch {
            DDLogError("Error while saving image to disk: \(error)")
        }
    }

    func setItemProviders(_ itemProviders: [NSItemProvider]) {
        sections = [.importing]
        let perItemUnitCount: Int64 = 10
        importProgress = Progress(totalUnitCount: Int64(itemProviders.count) * perItemUnitCount)
        progressObserver = importProgress?.observe(\.fractionCompleted) { (_, _) in
            // Observe progress to update table view when import is finished
            DispatchQueue.main.async { [weak self] in
                self?.updateTableViewAfterImport()
            }
        }
        for itemProvider in itemProviders {
            if itemProvider.hasItemConformingToTypeIdentifier(UTI.url.identifier) && !itemProvider.hasItemConformingToTypeIdentifier(UTI.fileURL.identifier) {
                // We don't handle saving web url, only file url
                importProgress?.completedUnitCount += perItemUnitCount
            } else if itemProvider.canLoadObject(ofClass: UIImage.self) {
                let childProgress = getPhoto(from: itemProvider) { (image) in
                    if let data = image?.jpegData(compressionQuality: self.JPEG_QUALITY) {
                        var name = itemProvider.suggestedName ?? SaveFileViewController.getDefaultFileName()
                        name = name.hasSuffix(".jpeg") ? name : "\(name).jpeg"
                        self.save(data: data, name: name, uti: .jpeg)
                    }
                }
                importProgress?.addChild(childProgress, withPendingUnitCount: perItemUnitCount)
            } else if itemProvider.canLoadObject(ofClass: PHLivePhoto.self) {
                let childProgress = getLivePhoto(from: itemProvider) { (data) in
                    if let data = data {
                        var name = itemProvider.suggestedName ?? SaveFileViewController.getDefaultFileName()
                        name = name.hasSuffix(".jpeg") ? name : "\(name).jpeg"
                        self.save(data: data, name: name, uti: .jpeg)
                    }
                }
                importProgress?.addChild(childProgress, withPendingUnitCount: perItemUnitCount)
            } else if let typeIdentifier = itemProvider.registeredTypeIdentifiers.first {
                let childProgress = getFile(from: itemProvider, typeIdentifier: typeIdentifier) { (filename, url) in
                    if let url = url {
                        var name = itemProvider.suggestedName ?? filename ?? SaveFileViewController.getDefaultFileName()
                        if let ext = UTI(typeIdentifier)?.preferredFilenameExtension {
                            name = name.hasSuffix(".\(ext)") ? name : "\(name).\(ext)"
                        }
                        self.items.append(ImportedFile(name: name, path: url, uti: UTI(typeIdentifier) ?? .data))
                    }
                }
                importProgress?.addChild(childProgress, withPendingUnitCount: perItemUnitCount)
            } else {
                // For some reason registeredTypeIdentifiers is empty (shouldn't occur)
                importProgress?.completedUnitCount += perItemUnitCount
            }
        }
    }

    func getPhoto(from itemProvider: NSItemProvider, completion: @escaping (UIImage?) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 10)
        guard itemProvider.canLoadObject(ofClass: UIImage.self) else {
            completion(nil)
            progress.completedUnitCount = progress.totalUnitCount
            return progress
        }

        let childProgress = itemProvider.loadObject(ofClass: UIImage.self) { object, error in
            if let error = error {
                DDLogError("Error while loading UIImage: \(error)")
                completion(nil)
            }

            if let image = object as? UIImage {
                completion(image)
            } else {
                completion(nil)
            }
            progress.completedUnitCount += 2
        }
        progress.addChild(childProgress, withPendingUnitCount: 8)
        return progress
    }

    func getLivePhoto(from itemProvider: NSItemProvider, completion: @escaping (Data?) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 10)
        guard itemProvider.canLoadObject(ofClass: PHLivePhoto.self) else {
            completion(nil)
            progress.completedUnitCount = progress.totalUnitCount
            return progress
        }

        let childProgress = itemProvider.loadObject(ofClass: PHLivePhoto.self) { object, error in
            if let error = error {
                DDLogError("Error while loading PHLivePhoto: \(error)")
                completion(nil)
            }

            if let livePhoto = object as? PHLivePhoto {
                let livePhotoResources = PHAssetResource.assetResources(for: livePhoto)
                if let resource = livePhotoResources.first(where: { $0.type == .photo }) {
                    var data = Data()
                    PHAssetResourceManager.default().requestData(for: resource, options: nil) { (chunk) in
                        data.append(chunk)
                    } completionHandler: { (error) in
                        if let error = error {
                            DDLogError("Error while requesting live photo data: \(error)")
                            completion(nil)
                        } else {
                            completion(data)
                        }
                        progress.completedUnitCount += 2
                    }
                } else {
                    completion(nil)
                    progress.completedUnitCount += 2
                }
            } else {
                completion(nil)
                progress.completedUnitCount += 2
            }
        }
        progress.addChild(childProgress, withPendingUnitCount: 8)
        return progress
    }

    func getFile(from itemProvider: NSItemProvider, typeIdentifier: String, completion: @escaping (String?, URL?) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 10)
        let childProgress = itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
            if let error = error {
                DDLogError("Error while loading file representation: \(error)")
                completion(nil, nil)
            }

            guard let url = url else { return }

            let targetURL = DriveFileManager.constants.importDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: false)

            do {
                if FileManager.default.fileExists(atPath: targetURL.path) {
                    try FileManager.default.removeItem(at: targetURL)
                }

                try FileManager.default.copyItem(at: url, to: targetURL)

                completion(url.lastPathComponent, targetURL)
            } catch {
                DDLogError("Error while loading file representation: \(error)")
                completion(nil, nil)
            }
            progress.completedUnitCount += 2
        }
        progress.addChild(childProgress, withPendingUnitCount: 8)
        return progress
    }

    private func updateButton() {
        enableButton = selectedDirectory != nil && items.reduce(true) { $0 && !$1.name.isEmpty } && !importInProgress
    }

    private func updateTableViewAfterImport() {
        if !importInProgress {
            if skipOptionsSelection {
                if isViewLoaded {
                    didClickOnButton()
                }
            } else {
                sections = [.fileName, .driveSelection, .directorySelection]
                if isViewLoaded {
                    updateButton()
                    tableView.reloadData()
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setInfomaniakAppearanceNavigationBar()
        tableView.reloadData()
    }

    class func instantiate() -> SaveFileViewController {
        return UIStoryboard(name: "SaveFile", bundle: nil).instantiateViewController(withIdentifier: "SaveFileViewController") as! SaveFileViewController
    }

    class func instantiateInNavigationController(file: ImportedFile? = nil) -> TitleSizeAdjustingNavigationController {
        let saveViewController = instantiate()
        if let file = file {
            saveViewController.items = [file]
        }
        let navigationController = TitleSizeAdjustingNavigationController(rootViewController: saveViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    @IBAction func close(_ sender: Any) {
        importProgress?.cancel()
        navigationController?.dismiss(animated: true)
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
        case .fileName:
            let item = items[indexPath.row]
            if items.count > 1 {
                let cell = tableView.dequeueReusableCell(type: MenuTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == self.tableView(tableView, numberOfRowsInSection: indexPath.section) - 1)
                cell.accessoryImageView.image = KDriveAsset.edit.image
                cell.logoImage.image = ConvertedType.fromUTI(item.uti).icon
                cell.titleLabel.text = item.name
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(type: FileNameTableViewCell.self, for: indexPath)
                cell.textField.text = item.name
                cell.textDidChange = { [unowned self] text in
                    item.name = text ?? KDriveStrings.Localizable.allUntitledFileName
                    if let text = text, !text.isEmpty {
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
            cell.configure(with: selectedDriveFileManager.drive)
            return cell
        case .directorySelection:
            let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.configure(with: selectedDirectory, drive: selectedDriveFileManager.drive)
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
            return HomeTitleView.instantiate(title: KDriveStrings.Localizable.allPathTitle)
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
        if section == tableView.numberOfSections - 1 && !importInProgress && !skipOptionsSelection {
            let view = FooterButtonView.instantiate(title: KDriveStrings.Localizable.buttonSave)
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
                let alert = AlertFieldViewController(title: KDriveStrings.Localizable.buttonRename, placeholder: KDriveStrings.Localizable.hintInputFileName, text: item.name, action: KDriveStrings.Localizable.buttonSave, loading: false) { (newName) in
                    item.name = newName
                    tableView.reloadRows(at: [indexPath], with: .automatic)
                }
                alert.textFieldConfiguration = .fileNameConfiguration
                alert.textFieldConfiguration.selectedRange = item.name.startIndex..<(item.name.lastIndex(where: { $0 == "." }) ?? item.name.endIndex)
                present(alert, animated: true)
            }
        case .driveSelection:
            let selectDriveViewController = SelectDriveViewController.instantiate()
            selectDriveViewController.selectedDrive = selectedDriveFileManager.drive
            selectDriveViewController.delegate = self
            navigationController?.pushViewController(selectDriveViewController, animated: true)
        case .directorySelection:
            let selectFolderViewController = SelectFolderViewController.instantiate()
            selectFolderViewController.driveFileManager = selectedDriveFileManager
            selectFolderViewController.delegate = self
            navigationController?.pushViewController(selectFolderViewController, animated: true)
        default:
            break
        }
    }

}

// MARK: - SelectFolderDelegate
extension SaveFileViewController: SelectFolderDelegate {

    func didSelectFolder(_ folder: File) {
        if folder.id == DriveFileManager.constants.rootID {
            selectedDirectory = AccountManager.instance.currentDriveFileManager.getRootFile()
        } else {
            selectedDirectory = folder
        }
        updateButton()
    }
}

// MARK: - SelectDriveDelegate
extension SaveFileViewController: SelectDriveDelegate {

    func didSelectDrive(_ drive: Drive) {
        if let selectedDrive = AccountManager.instance.getDriveFileManager(for: drive) {
            selectedDriveFileManager = selectedDrive
            AccountManager.instance.setCurrentDriveForCurrentAccount(drive: drive)
            AccountManager.instance.saveAccounts()
            selectedDirectory = AccountManager.instance.currentDriveFileManager.getRootFile()
        }
        updateButton()
    }

}

// MARK: - FooterButtonDelegate
extension SaveFileViewController: FooterButtonDelegate {
    @objc func didClickOnButton() {
        guard let selectedDirectory = selectedDirectory else {
            return
        }

        if let uploadNewFile = selectedDirectory.rights?.uploadNewFile.value, !uploadNewFile {
            UIConstants.showSnackBar(message: KDriveStrings.Localizable.allFileAddRightError)
            return
        }

        for item in items {
            let newFile = UploadFile(
                parentDirectoryId: selectedDirectory.id,
                userId: AccountManager.instance.currentAccount.userId,
                driveId: selectedDriveFileManager.drive.id,
                url: item.path,
                name: item.name
            )
            UploadQueue.instance.addToQueue(file: newFile)
        }
        //Restore original drive only if the user didn't switch account
        if originalUserId == AccountManager.instance.currentUserId && originalDriveId != selectedDriveFileManager.drive.objectId,
            let originalDrive = DriveInfosManager.instance.getDrive(objectId: originalDriveId) {
            AccountManager.instance.setCurrentDriveForCurrentAccount(drive: originalDrive)
            AccountManager.instance.saveAccounts()
        }
        navigationController?.dismiss(animated: true) { [self] in
            let message = items.count > 1 ? KDriveStrings.Localizable.allUploadInProgressPlural(items.count) : KDriveStrings.Localizable.allUploadInProgress(items[0].name)
            UIConstants.showSnackBar(message: message)
        }
    }
}
