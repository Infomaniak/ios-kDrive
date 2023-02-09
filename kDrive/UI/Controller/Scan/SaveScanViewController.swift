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
import kDriveResources
import PDFKit
import UIKit
import Vision
import VisionKit

class SaveScanViewController: SaveFileViewController {
    var scan: VNDocumentCameraScan!
    var scanType = ScanFileFormat(rawValue: 0)!

    override func viewDidLoad() {
        tableView.register(cellView: ScanTypeTableViewCell.self)
        super.viewDidLoad()
        sections = [.fileName, .fileType, .directorySelection]
        detectFileName()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .fileType:
            let cell = tableView.dequeueReusableCell(type: ScanTypeTableViewCell.self, for: indexPath)
            cell.didSelectIndex = { [weak self] index in
                self?.scanType = ScanFileFormat(rawValue: index)!
            }
            cell.configureWith(scan: scan)
            return cell
        default:
            return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .fileType:
            return HomeTitleView.instantiate(title: KDriveResourcesStrings.Localizable.searchFilterTitle)
        default:
            return super.tableView(tableView, viewForHeaderInSection: section)
        }
    }

    override func didClickOnButton() {
        let footer = tableView.footerView(forSection: sections.count - 1) as! FooterButtonView
        footer.footerButton.setLoading(true)
        guard let filename = items.first?.name,
              let selectedDriveFileManager = selectedDriveFileManager,
              let selectedDirectory = selectedDirectory else {
            footer.footerButton.setLoading(false)
            return
        }

        DispatchQueue.global(qos: .userInteractive).async { [self] in
            do {
                try fileImportHelper.upload(
                    scan: scan,
                    name: filename,
                    scanType: scanType,
                    in: selectedDirectory,
                    drive: selectedDriveFileManager.drive
                )
                Task {
                    let parent = presentingViewController
                    footer.footerButton.setLoading(false)
                    dismiss(animated: true) {
                        parent?.dismiss(animated: true) {
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.allUploadInProgress(filename))
                        }
                    }
                }
            } catch {
                Task {
                    footer.footerButton.setLoading(false)
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorUpload)
                }
            }
        }
    }

    override class func instantiate(driveFileManager: DriveFileManager?) -> SaveScanViewController {
        let viewController = Storyboard.scan.instantiateViewController(withIdentifier: "SaveScanViewController") as! SaveScanViewController
        viewController.selectedDriveFileManager = driveFileManager
        return viewController
    }

    private func detectFileName() {
        // Get the first page
        guard let cgImage = scan.imageOfPage(at: 0).cgImage else { return }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)

        do {
            // Perform the text-recognition request
            try requestHandler.perform([request])
        } catch {
            DDLogInfo("[Scan] Unable to perform the requests: \(error).")
        }
    }

    func recognizeTextHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        let minConfidence: Float = 0.6
        let recognizedStrings: [String] = observations.compactMap { observation in
            // Return the string of the top VNRecognizedText instance
            let topCandidate = observation.topCandidates(1).first
            if let topCandidate = topCandidate, topCandidate.confidence >= minConfidence {
                return topCandidate.string
            } else {
                return nil
            }
        }

        // Use the first string as the filename
        guard let firstResult = recognizedStrings.first else { return }
        items.first?.name = firstResult.localizedCapitalized
        tableView.reloadData()
    }
}
