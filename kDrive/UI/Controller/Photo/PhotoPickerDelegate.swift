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
import kDriveCore
import Photos
import PhotosUI
import UIKit

class PhotoPickerDelegate: NSObject {
    var driveFileManager: DriveFileManager!
    var currentDirectory: File!
}

// MARK: - Image picker controller delegate

extension PhotoPickerDelegate: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        guard let mediaType = info[.mediaType] as? String, let uti = UTI(mediaType) else {
            return
        }

        switch uti {
        case .image:
            guard let image = info[.originalImage] as? UIImage else {
                return
            }
            do {
                try FileImportHelper.instance.upload(photo: image, name: FileImportHelper.instance.getDefaultFileName(), format: .jpg, in: currentDirectory, drive: driveFileManager.drive)
            } catch {
                UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorUpload)
            }
        case .movie:
            guard let selectedVideo = info[.mediaURL] as? URL else {
                return
            }
            do {
                try FileImportHelper.instance.upload(videoUrl: selectedVideo, name: FileImportHelper.instance.getDefaultFileName(), in: currentDirectory, drive: driveFileManager.drive)
            } catch {
                UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorUpload)
            }
        default:
            break
        }
    }
}

// MARK: - Picker view controller delegate

@available(iOS 14, *)
extension PhotoPickerDelegate: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) {
            UIConstants.showSnackBar(message: KDriveStrings.Localizable.snackbarProcessingUploads)
        }

        if !results.isEmpty {
            _ = FileImportHelper.instance.importItems(results.map(\.itemProvider)) { importedFiles in
                let message: String
                do {
                    try FileImportHelper.instance.upload(files: importedFiles, in: self.currentDirectory, drive: self.driveFileManager.drive)
                    message = importedFiles.count > 1 ? KDriveStrings.Localizable.allUploadInProgressPlural(importedFiles.count) : KDriveStrings.Localizable.allUploadInProgress(importedFiles[0].name)
                } catch {
                    message = KDriveStrings.Localizable.errorUpload
                }
                DispatchQueue.main.async {
                    UIConstants.showSnackBar(message: message)
                }
            }
        }
    }
}
