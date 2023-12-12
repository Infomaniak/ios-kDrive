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
import Vision
import VisionKit

/// Something to process a document and extract text from it
public protocol SaveScanWorkable: AnyObject {
    /// Start the document processing, result is dispatched with `resultDelegate`
    func detectFileName() async

    init(scan: VNDocumentCameraScan, resultDelegate: SaveScanWorkerDelegate)
}

public final class SaveScanWorker: SaveScanWorkable {
    /// The VisionKit document
    private let scan: VNDocumentCameraScan

    /// Used to send the result of the processing
    private weak var resultDelegate: SaveScanWorkerDelegate?

    public init(scan: VNDocumentCameraScan, resultDelegate: SaveScanWorkerDelegate) {
        self.scan = scan
        self.resultDelegate = resultDelegate
    }

    public func detectFileName() async {
        // Get the first page
        guard let cgImage = scan.imageOfPage(at: 0).cgImage else { return }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)

        do {
            // Perform the text-recognition request
            try requestHandler.perform([request])
        } catch {
            DDLogError("[Scan] Unable to perform the requests: \(error).")
        }
    }

    private func recognizeTextHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        let minConfidence: Float = 0.6
        let recognizedStrings: [String] = observations.compactMap { observation in
            // Return the string of the top VNRecognizedText instance
            let topCandidate = observation.topCandidates(1).first
            if let topCandidate, topCandidate.confidence >= minConfidence {
                return topCandidate.string
            } else {
                return nil
            }
        }

        Task { @MainActor in
            self.resultDelegate?.recognizedStrings(recognizedStrings)
        }
    }
}
