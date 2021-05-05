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
import kDriveCore
import Photos
import PhotosUI
import CocoaLumberjackSwift

class PhotoPickerDelegate: NSObject {

    var currentDirectory: File!
    var viewController: UIViewController!

    func handleError(_ error: Error?) {
        if let error = error {
            DDLogError("Error while selecting media: \(error)")
        }
        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
    }

}

// MARK: - Image picker controller delegate

extension PhotoPickerDelegate: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        let savePhotoNavigationViewController = SavePhotoViewController.instantiateInNavigationController()

        guard let savePhotoVC = savePhotoNavigationViewController.viewControllers.first as? SavePhotoViewController,
            let mediaType = info[.mediaType] as? String, let uti = UTI(mediaType) else {
            return
        }

        savePhotoVC.uti = uti
        savePhotoVC.selectedDirectory = currentDirectory
        savePhotoVC.items = [.init(name: SavePhotoViewController.getDefaultFileName(), path: URL(string: "/")!, uti: uti)]
        savePhotoVC.skipOptionsSelection = true

        switch uti {
        case .image:
            guard let image = info[.originalImage] as? UIImage else {
                return picker.dismiss(animated: true)
            }
            savePhotoVC.photo = image
        case .movie:
            guard let selectedVideo = info[.mediaURL] as? URL else {
                return picker.dismiss(animated: true)
            }
            savePhotoVC.videoUrl = selectedVideo
        default:
            break
        }

        if picker.sourceType == .camera {
            // Don't present view
            picker.dismiss(animated: true) {
                savePhotoVC.didClickOnButton()
            }
        } else {
            viewController.present(savePhotoNavigationViewController, animated: true)
        }
    }

}

// MARK: - Picker view controller delegate

@available(iOS 14, *)
extension PhotoPickerDelegate: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        if results.count > 0 {
            let saveFileNavigationViewController = SaveFileViewController.instantiateInNavigationController()

            guard let saveFileVC = saveFileNavigationViewController.viewControllers.first as? SaveFileViewController else {
                return
            }
            saveFileVC.selectedDirectory = currentDirectory
            saveFileVC.skipOptionsSelection = true
            saveFileVC.setItemProviders(results.map(\.itemProvider))

            viewController.present(saveFileNavigationViewController, animated: true)
        }
    }

}
