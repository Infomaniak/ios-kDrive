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
import InfomaniakDI
import kDriveCore
import kDriveResources
import Photos
import PhotosUI
import UIKit

class PhotoPickerDelegate: NSObject {
    @LazyInjectService var fileImportHelper: FileImportHelper

    var driveFileManager: DriveFileManager!
    var currentDirectory: File!

    weak var viewController: UIViewController?

    @MainActor
    private func handleError(_ error: Error) {
        DDLogError("Error while uploading file: \(error)")
        UIConstants.showSnackBarIfNeeded(error: error)
    }

    @MainActor
    private func showUploadSnackbar(count: Int, filename: String) {
//        let message = count > 1 ? KDriveResourcesStrings.Localizable.allUploadInProgressPlural(count) : KDriveResourcesStrings
//            .Localizable.allUploadInProgress(filename)
//        UIConstants.showSnackBar(message: message)
    }
}

// MARK: - Image picker controller delegate

extension PhotoPickerDelegate: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        guard let mediaType = info[.mediaType] as? String, let uti = UTI(mediaType) else {
            return
        }

        switch uti {
        case .image:
            guard let image = info[.originalImage] as? UIImage else {
                return
            }
            let filename = FileImportHelper.getDefaultFileName()
            do {
                try fileImportHelper.upload(photo: image,
                                            name: filename,
                                            format: .jpg,
                                            in: currentDirectory,
                                            drive: driveFileManager.drive)
                showUploadSnackbar(count: 1, filename: filename)
            } catch {
                handleError(error)
            }
        case .movie:
            guard let selectedVideo = info[.mediaURL] as? URL else {
                return
            }
            let filename = FileImportHelper.getDefaultFileName()
            do {
                try fileImportHelper.upload(videoUrl: selectedVideo,
                                            name: filename,
                                            in: currentDirectory,
                                            drive: driveFileManager.drive)
                showUploadSnackbar(count: 1, filename: filename)
            } catch {
                handleError(error)
            }
        default:
            break
        }
    }
}

// MARK: - Picker view controller delegate

extension PhotoPickerDelegate: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        if !results.isEmpty {
            let saveNavigationViewController = SaveFileViewController
                .instantiateInNavigationController(driveFileManager: driveFileManager)
            if let saveViewController = saveNavigationViewController.viewControllers.first as? SaveFileViewController {
                saveViewController.assetIdentifiers = results.compactMap(\.assetIdentifier)
                saveViewController.selectedDirectory = currentDirectory
                viewController?.present(saveNavigationViewController, animated: true)
            }
        }
    }
}
