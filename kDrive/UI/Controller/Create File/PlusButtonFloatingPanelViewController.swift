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
import FloatingPanel
import Vision
import VisionKit
import PhotosUI
import AVFoundation
import kDriveCore

class PlusButtonFloatingPanelViewController: UITableViewController, FloatingPanelControllerDelegate {

    var currentDirectory: File!

    private struct PlusButtonMenuAction: Equatable {
        let name: String
        let image: UIImage
        var color: UIColor = KDriveAsset.iconColor.color
        var docType: String = ""

        static let takePictureAction = PlusButtonMenuAction(name: KDriveStrings.Localizable.buttonTakePhotoOrVideo, image: KDriveAsset.camera.image)
        static let importMediaAction = PlusButtonMenuAction(name: KDriveStrings.Localizable.buttonUploadPhotoOrVideo, image: KDriveAsset.images.image)
        static let importAction = PlusButtonMenuAction(name: KDriveStrings.Localizable.buttonUploadFile, image: KDriveAsset.upload.image)
        static let scanAction = PlusButtonMenuAction(name: KDriveStrings.Localizable.buttonDocumentScanning, image: KDriveAsset.scan.image)
        static let folderAction = PlusButtonMenuAction(name: KDriveStrings.Localizable.allFolder, image: KDriveAsset.folderFill.image)

        static let docsAction = PlusButtonMenuAction(name: KDriveStrings.Localizable.allOfficeDocs, image: KDriveAsset.fileText.image, color: KDriveAsset.infomaniakColor.color, docType: "docx")
        static let pointsAction = PlusButtonMenuAction(name: KDriveStrings.Localizable.allOfficePoints, image: KDriveAsset.filePresentation.image, docType: "pptx")
        static let gridsAction = PlusButtonMenuAction(name: KDriveStrings.Localizable.allOfficeGrids, image: KDriveAsset.fileSheets.image, docType: "xlsx")
        static let noteAction = PlusButtonMenuAction(name: KDriveStrings.Localizable.allOfficeNote, image: KDriveAsset.fileText.image, color: KDriveAsset.secondaryTextColor.color, docType: "txt")
    }

    private var content: [[PlusButtonMenuAction]] = [
        [],
        [.scanAction, .takePictureAction, .importMediaAction, .importAction, .folderAction],
        [.docsAction, .gridsAction, .pointsAction, .noteAction]
    ]

    var contentHeight: CGFloat {
        get {
            return content.reduce(CGFloat(100)) { (last, section) in
                return last + CGFloat(60 * section.count)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.separatorColor = .clear
        tableView.alwaysBounceVertical = false
        tableView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
        tableView.register(cellView: FloatingPanelTableViewCell.self)
        tableView.register(cellView: FloatingPanelTitleTableViewCell.self)

        // Hide unavailable actions
        #if !DEBUG
            if #available(iOS 13.0, *), VNDocumentCameraViewController.isSupported {
                // Action is available: do nothing
            } else {
                content[1].removeAll(where: { $0 == .scanAction })
            }
            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                content[1].removeAll(where: { $0 == .takePictureAction })
            }
            if !UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                content[1].removeAll(where: { $0 == .importMediaAction })
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
            cell.titleLabel.text = currentDirectory.id == DriveFileManager.constants.rootID ? KDriveStrings.Localizable.allRootName(AccountManager.instance.currentDriveFileManager.drive.name) : currentDirectory.name
            cell.accessoryImageView.image = currentDirectory.id == DriveFileManager.constants.rootID ? KDriveAsset.drive.image : KDriveAsset.folderFilled.image
            cell.accessoryImageView.tintColor = currentDirectory.id == DriveFileManager.constants.rootID ? UIColor(hex: AccountManager.instance.currentDriveFileManager.drive.preferences.color) : nil
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
        guard let mainTabViewController = parent?.presentingViewController as? MainTabViewController else { return }
        let action = content[indexPath.section][indexPath.row]
        switch action {
        case .importAction:
            let documentPicker = DriveImportDocumentPickerViewController(documentTypes: [UTI.data.identifier], in: .import)
            documentPicker.importDriveDirectory = currentDirectory
            documentPicker.delegate = mainTabViewController
            mainTabViewController.present(documentPicker, animated: true)
        case .folderAction:
            let newFolderViewController = NewFolderTypeTableViewController.instantiateInNavigationController(parentDirectory: currentDirectory, driveFileManager: AccountManager.instance.currentDriveFileManager)
            mainTabViewController.present(newFolderViewController, animated: true)
        case .scanAction:
            if #available(iOS 13.0, *), VNDocumentCameraViewController.isSupported {
                let scanDoc = VNDocumentCameraViewController()
                let navigationViewController = ScanNavigationViewController(rootViewController: scanDoc)
                navigationViewController.modalPresentationStyle = .fullScreen
                navigationViewController.currentDirectory = currentDirectory
                scanDoc.delegate = navigationViewController
                mainTabViewController.present(navigationViewController, animated: true)
            } else {
                print("VNDocumentCameraViewController is not supported on this device")
            }
        case .takePictureAction, .importMediaAction:
            mainTabViewController.photoPickerDelegate.currentDirectory = currentDirectory
            mainTabViewController.photoPickerDelegate.viewController = mainTabViewController

            if #available(iOS 14, *), action == .importMediaAction {
                // Present new photo picker
                var configuration = PHPickerConfiguration()
                configuration.selectionLimit = 0

                let picker = PHPickerViewController(configuration: configuration)
                picker.delegate = mainTabViewController.photoPickerDelegate
                mainTabViewController.present(picker, animated: true)
            } else {
                // Present camera or old photo picker
                let sourceType: UIImagePickerController.SourceType = action == .takePictureAction ? .camera : .photoLibrary

                guard sourceType != .camera || AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
                    let alert = AlertTextViewController(title: KDriveStrings.Localizable.cameraAccessDeniedTitle, message: KDriveStrings.Localizable.cameraAccessDeniedDescription, action: KDriveStrings.Localizable.buttonGoToSettings) {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settingsUrl) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    mainTabViewController.present(alert, animated: true)
                    return
                }

                if UIImagePickerController.isSourceTypeAvailable(sourceType) {
                    let picker = UIImagePickerController()
                    picker.sourceType = sourceType
                    picker.delegate = mainTabViewController.photoPickerDelegate
                    picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: sourceType) ?? [UTI.image.identifier, UTI.movie.identifier]
                    mainTabViewController.present(picker, animated: true)
                } else {
                    print("Source type \(sourceType) is not available on this device")
                }
            }
        case .docsAction, .gridsAction, .pointsAction, .noteAction:
            let alertViewController = AlertDocViewController(fileType: action.docType, directory: currentDirectory)
            mainTabViewController.present(alertViewController, animated: true)
        default:
            break
        }
    }

    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout {
        return PlusButtonFloatingPanelLayout(height: min(contentHeight + view.safeAreaInsets.bottom, UIScreen.main.bounds.size.height - 48))
    }

    open override func accessibilityPerformEscape() -> Bool {
        dismiss(animated: true)
        return true
    }

    func floatingPanel(_ fpc: FloatingPanelController, shouldRemoveAt location: CGPoint, with velocity: CGVector) -> Bool {
        // Remove the panel when it's pushed one third down
        return location.y > fpc.backdropView.frame.height * 1 / 3
    }

}
