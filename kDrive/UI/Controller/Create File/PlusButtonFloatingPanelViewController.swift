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
import CocoaLumberjackSwift
import FloatingPanel
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import kDriveResources
import PhotosUI
import UIKit
import Vision
import VisionKit

class PlusButtonFloatingPanelViewController: UITableViewController, FloatingPanelControllerDelegate {
    @LazyInjectService var constants: DriveConstants

    var currentDirectory: File!
    var driveFileManager: DriveFileManager!

    let presentedFromPlusButton: Bool
    let presentedAboveFileList: Bool

    private struct PlusButtonMenuAction: Equatable {
        let name: String
        let image: UIImage
        var color: UIColor = KDriveResourcesAsset.iconColor.color
        var docType = ""
        var matomoName = ""

        static let takePictureAction = PlusButtonMenuAction(
            name: KDriveResourcesStrings.Localizable.buttonTakePhotoOrVideo,
            image: KDriveResourcesAsset.camera.image,
            matomoName: "takePhotoOrVideo"
        )
        static let importMediaAction = PlusButtonMenuAction(
            name: KDriveResourcesStrings.Localizable.buttonUploadPhotoOrVideo,
            image: KDriveResourcesAsset.images.image,
            matomoName: "uploadMedia"
        )
        static let importAction = PlusButtonMenuAction(
            name: KDriveResourcesStrings.Localizable.buttonUploadFile,
            image: KDriveResourcesAsset.upload.image,
            matomoName: "uploadFile"
        )
        static let scanAction = PlusButtonMenuAction(
            name: KDriveResourcesStrings.Localizable.buttonDocumentScanning,
            image: KDriveResourcesAsset.scan.image,
            matomoName: "scan"
        )
        static let folderAction = PlusButtonMenuAction(
            name: KDriveResourcesStrings.Localizable.allFolder,
            image: KDriveResourcesAsset.folderFilled.image.withRenderingMode(.alwaysTemplate)
        )

        static let docsAction = PlusButtonMenuAction(
            name: KDriveResourcesStrings.Localizable.allOfficeDocs,
            image: KDriveResourcesAsset.fileText.image,
            color: KDriveResourcesAsset.infomaniakColor.color,
            docType: "docx",
            matomoName: "createDocument"
        )
        static let pointsAction = PlusButtonMenuAction(
            name: KDriveResourcesStrings.Localizable.allOfficePoints,
            image: KDriveResourcesAsset.filePresentation.image,
            docType: "pptx",
            matomoName: "createPresentation"
        )
        static let gridsAction = PlusButtonMenuAction(
            name: KDriveResourcesStrings.Localizable.allOfficeGrids,
            image: KDriveResourcesAsset.fileSheets.image,
            docType: "xlsx",
            matomoName: "createTable"
        )
        static let formAction = PlusButtonMenuAction(
            name: KDriveResourcesStrings.Localizable.allOfficeForm,
            image: KDriveResourcesAsset.fileForm.image,
            docType: "docxf",
            matomoName: "createForm"
        )
        static let noteAction = PlusButtonMenuAction(
            name: KDriveResourcesStrings.Localizable.allOfficeNote,
            image: KDriveResourcesAsset.fileText.image,
            color: KDriveResourcesAsset.secondaryTextColor.color,
            docType: "txt",
            matomoName: "createText"
        )
    }

    private var content: [[PlusButtonMenuAction]] = [
        [],
        [.scanAction, .takePictureAction, .importMediaAction, .importAction, .folderAction],
        [.docsAction, .gridsAction, .pointsAction, .noteAction]
    ]

    init(
        driveFileManager: DriveFileManager,
        folder: File,
        presentedFromPlusButton: Bool = true,
        presentedAboveFileList: Bool = true
    ) {
        self.driveFileManager = driveFileManager
        currentDirectory = folder
        self.presentedFromPlusButton = presentedFromPlusButton
        self.presentedAboveFileList = presentedAboveFileList
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.separatorColor = .clear
        tableView.alwaysBounceVertical = false
        tableView.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        tableView.register(cellView: FloatingPanelTableViewCell.self)

        // Hide unavailable actions
        #if !DEBUG
        if !VNDocumentCameraViewController.isSupported {
            content[1].removeAll { $0 == .scanAction }
        }
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            content[1].removeAll { $0 == .takePictureAction }
        }
        if !UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            content[1].removeAll { $0 == .importMediaAction }
        }
        #endif
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 && indexPath.section == 0 {
            return UIConstants.floatingPanelHeaderHeight
        } else {
            return UITableView.automaticDimension
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return content.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return content[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: FloatingPanelTableViewCell.self, for: indexPath)
        if indexPath.section == 0 {
            cell.titleLabel.text = currentDirectory.id == constants.rootID ? KDriveResourcesStrings.Localizable
                .allRootName(driveFileManager.drive.name) : currentDirectory.name
            cell.accessoryImageView.image = currentDirectory.id == constants.rootID ? KDriveResourcesAsset.drive
                .image : KDriveResourcesAsset.folderFilled.image
            cell.accessoryImageView.tintColor = currentDirectory.id == constants
                .rootID ? UIColor(hex: driveFileManager.drive.preferences.color) : nil
            cell.separator?.isHidden = false
            cell.selectionStyle = .none
            cell.accessibilityTraits = .header
            return cell
        }

        let action = content[indexPath.section][indexPath.row]

        cell.titleLabel.text = action.name
        cell.accessoryImageView.image = action.image
        cell.accessoryImageView.tintColor = action.color

        if indexPath.row < content[indexPath.section].count - 1 {
            cell.separator?.isHidden = true
        } else {
            if indexPath.section == 2 {
                cell.separator?.isHidden = true
            } else {
                cell.separator?.isHidden = false
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            return
        }
        dismiss(animated: true)

        guard let mainTabViewController = parent?.presentingViewController as? MainTabViewController else {
            return
        }

        let action = content[indexPath.section][indexPath.row]
        // Folder creation is already tracked through its creation page
        if action != .folderAction {
            let suffix = presentedFromPlusButton ? "FromFAB" : "FromFolder"
            MatomoUtils.track(eventWithCategory: .newElement, name: "\(action.matomoName)\(suffix)")
        }

        switch action {
        case .importAction:
            importAction(mainTabViewController)
        case .folderAction:
            folderAction(mainTabViewController)
        case .scanAction:
            scanAction(mainTabViewController)
        case .takePictureAction, .importMediaAction:
            mediaAction(mainTabViewController, action: action)
        case .docsAction, .gridsAction, .pointsAction, .formAction, .noteAction:
            documentAction(mainTabViewController, action: action)
        default:
            break
        }
    }

    override open func accessibilityPerformEscape() -> Bool {
        dismiss(animated: true)
        return true
    }

    func floatingPanel(_ fpc: FloatingPanelController, shouldRemoveAt location: CGPoint, with velocity: CGVector) -> Bool {
        // Remove the panel when it's pushed one third down
        return location.y > fpc.backdropView.frame.height * 1 / 3
    }

    // MARK: Actions

    private func importAction(_ mainTabViewController: MainTabViewController) {
        let documentPicker = DriveImportDocumentPickerViewController(documentTypes: [UTI.data.identifier], in: .import)
        documentPicker.importDrive = driveFileManager.drive
        documentPicker.importDriveDirectory = currentDirectory.freezeIfNeeded()
        documentPicker.delegate = mainTabViewController
        mainTabViewController.present(documentPicker, animated: true)
    }

    private func folderAction(_ mainTabViewController: MainTabViewController) {
        let newFolderViewController = NewFolderTypeTableViewController.instantiateInNavigationController(
            parentDirectory: currentDirectory,
            driveFileManager: driveFileManager
        )
        mainTabViewController.present(newFolderViewController, animated: true)
    }

    private func scanAction(_ mainTabViewController: MainTabViewController) {
        guard VNDocumentCameraViewController.isSupported else {
            DDLogError("VNDocumentCameraViewController is not supported on this device")
            return
        }

        let scanDoc = VNDocumentCameraViewController()
        let navigationViewController = ScanNavigationViewController(rootViewController: scanDoc)
        navigationViewController.modalPresentationStyle = .fullScreen
        navigationViewController.currentDriveFileManager = driveFileManager
        if presentedAboveFileList {
            navigationViewController.currentDirectory = currentDirectory.freezeIfNeeded()
        }
        scanDoc.delegate = navigationViewController
        mainTabViewController.present(navigationViewController, animated: true)
    }

    private func mediaAction(_ mainTabViewController: MainTabViewController, action: PlusButtonMenuAction) {
        let openMediaHelper = OpenMediaHelper(currentDirectory: currentDirectory, driveFileManager: driveFileManager)
        openMediaHelper.openMedia(mainTabViewController, action == .importMediaAction ? .library : .camera)
    }

    private func documentAction(_ mainTabViewController: MainTabViewController, action: PlusButtonMenuAction) {
        let alertViewController = AlertDocViewController(fileType: action.docType,
                                                         directory: currentDirectory.freezeIfNeeded(),
                                                         driveFileManager: driveFileManager)
        mainTabViewController.present(alertViewController, animated: true)
    }
}
