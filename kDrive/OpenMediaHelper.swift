/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import Foundation
import InfomaniakCore
import kDriveCore
import kDriveResources
import PhotosUI
import Vision
import VisionKit

struct OpenMediaHelper {
    var currentDirectory: File?
    var driveFileManager: DriveFileManager

    enum Media {
        case library, camera
    }

    func openMedia(_ mainTabViewController: MainTabViewController, _ media: Media) {
        mainTabViewController.photoPickerDelegate.driveFileManager = driveFileManager
        mainTabViewController.photoPickerDelegate.currentDirectory = currentDirectory?.freezeIfNeeded()

        if media == .library {
            // Check permission
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { authorizationStatus in
                if authorizationStatus == .authorized {
                    Task { @MainActor in
                        var configuration = PHPickerConfiguration(photoLibrary: .shared())
                        configuration.selectionLimit = 0

                        let picker = PHPickerViewController(configuration: configuration)
                        picker.delegate = mainTabViewController.photoPickerDelegate
                        mainTabViewController.present(picker, animated: true)
                    }
                } else {
                    Task { @MainActor in
                        let alert = AlertTextViewController(
                            title: KDriveResourcesStrings.Localizable.photoLibraryAccessLimitedTitle,
                            message: KDriveResourcesStrings.Localizable.photoLibraryAccessLimitedDescription,
                            action: KDriveResourcesStrings.Localizable.buttonGoToSettings
                        ) {
                            Constants.openSettings()
                        }
                        mainTabViewController.present(alert, animated: true)
                    }
                }
            }
        } else {
            // Present camera or old photo picker
            let sourceType: UIImagePickerController.SourceType = media == .camera ? .camera : .photoLibrary

            guard sourceType != .camera || AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
                let alert = AlertTextViewController(
                    title: KDriveResourcesStrings.Localizable.cameraAccessDeniedTitle,
                    message: KDriveResourcesStrings.Localizable.cameraAccessDeniedDescription,
                    action: KDriveResourcesStrings.Localizable.buttonGoToSettings
                ) {
                    Constants.openSettings()
                }
                mainTabViewController.present(alert, animated: true)
                return
            }

            guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
                DDLogError("Source type \(sourceType) is not available on this device")
                return
            }

            let picker = UIImagePickerController()
            picker.sourceType = sourceType
            picker.delegate = mainTabViewController.photoPickerDelegate
            picker.mediaTypes = UIImagePickerController
                .availableMediaTypes(for: sourceType) ?? [UTI.image.identifier, UTI.movie.identifier]
            mainTabViewController.present(picker, animated: true)
        }
    }

    func openScan(_ mainTabViewController: MainTabViewController, _ presentedAboveFileList: Bool) {
        guard VNDocumentCameraViewController.isSupported else {
            DDLogError("VNDocumentCameraViewController is not supported on this device")
            return
        }

        let scanDoc = VNDocumentCameraViewController()
        let navigationViewController = ScanNavigationViewController(rootViewController: scanDoc)
        navigationViewController.modalPresentationStyle = .fullScreen
        navigationViewController.currentDriveFileManager = driveFileManager
        if presentedAboveFileList {
            navigationViewController.currentDirectory = currentDirectory?.freezeIfNeeded()
        }
        scanDoc.delegate = navigationViewController
        mainTabViewController.present(navigationViewController, animated: true)
    }
}
