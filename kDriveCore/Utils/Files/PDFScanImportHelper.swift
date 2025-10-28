/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

import Foundation
import VisionKit

struct PDFScanImportHelper {
    /// Get a standard printable page size
    private var pageRect: CGRect {
        let locale = NSLocale.current
        let isMetric = locale.usesMetricSystem

        // Size is expressed in PostScript points
        let pageSize: CGSize
        if isMetric {
            // Using A4
            let metricPageSize = CGSize(width: 595.28, height: 841.89)
            pageSize = metricPageSize
        } else {
            // Using LETTER US
            let freedomPageSize = CGSize(width: 612.00, height: 792.00)
            pageSize = freedomPageSize
        }

        return CGRect(origin: .zero, size: pageSize)
    }

    func convertScanToPDF(scan: VNDocumentCameraScan) -> Data? {
        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return nil
        }

        for pageIndex in 0 ..< scan.pageCount {
            let pageImage = scan.imageOfPage(at: pageIndex)
            guard let pageData = pageImage.jpegData(compressionQuality: FileImportHelper.imageCompression),
                  let compressedPageImage = UIImage(data: pageData) else {
                return nil
            }

            guard let cgImage = compressedPageImage.cgImage else { continue }
            autoreleasepool {
                let imageSize = compressedPageImage.size
                let aspectRatio = imageSize.width / imageSize.height
                let pageAspectRatio = pageRect.width / pageRect.height

                let aspectRatioTolerance: CGFloat = 0.1
                let aspectRatioDifference = abs(aspectRatio - pageAspectRatio) / pageAspectRatio

                let drawRect: CGRect
                if aspectRatioDifference <= aspectRatioTolerance {
                    var mediaBox = pageRect
                    pdfContext.beginPage(mediaBox: &mediaBox)
                    drawRect = pageRect
                } else {
                    var mediaBox = CGRect(origin: .zero, size: compressedPageImage.size)
                    pdfContext.beginPage(mediaBox: &mediaBox)
                    let xOffset = (mediaBox.width - imageSize.width) / 2
                    let yOffset = (mediaBox.height - imageSize.height) / 2
                    drawRect = CGRect(x: xOffset, y: yOffset, width: imageSize.width, height: imageSize.height)
                }

                pdfContext.draw(cgImage, in: drawRect)

                pdfContext.endPage()
            }
        }

        pdfContext.closePDF()

        return pdfData as Data
    }
}
