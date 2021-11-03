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
import Vision
import VisionKit
import kDriveCore

class ScanNavigationViewController: UINavigationController {

    var currentDriveFileManager: DriveFileManager?
    var currentDirectory: File!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setInfomaniakAppearanceNavigationBar()
        setNavigationBarHidden(true, animated: false)
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate

extension ScanNavigationViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        guard scan.pageCount >= 1 else {
            controller.dismiss(animated: true)
            return
        }
        let saveScanNavigationViewController = SaveScanViewController.instantiateInNavigationController(driveFileManager: currentDriveFileManager)
        saveScanNavigationViewController.modalPresentationStyle = .fullScreen
        if let saveScanVC = saveScanNavigationViewController.viewControllers.first as? SaveScanViewController {
            saveScanVC.items = [.init(name: FileImportHelper.instance.getDefaultFileName(), path: URL(string: "/")!, uti: .data)]
            saveScanVC.scan = scan
            saveScanVC.selectedDirectory = currentDirectory
        }
        present(saveScanNavigationViewController, animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true)
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }
}
