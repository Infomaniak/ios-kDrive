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
import PDFKit
import kDriveCore

class PdfPreviewCollectionViewCell: PreviewCollectionViewCell, UIScrollViewDelegate {

    @IBOutlet weak var pdfPreview: PDFView!
    private var document: PDFDocument?

    override func awakeFromNib() {
        super.awakeFromNib()
        pdfPreview.autoScales = true
        pdfPreview.enableDataDetectors = true
        pdfPreview.backgroundColor = KDriveAsset.previewBackgroundColor.color
    }

    @objc private func pageChanged() {
        previewDelegate?.updateNavigationBar()
    }

    override func configureWith(file: File) {
        NotificationCenter.default.addObserver(self, selector: #selector(pageChanged), name: .PDFViewPageChanged, object: pdfPreview)
        document = PDFDocument(url: file.localUrl)
        pdfPreview.document = document
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        NotificationCenter.default.removeObserver(self, name: .PDFViewPageChanged, object: pdfPreview)
        pdfPreview.document = nil
    }

}

extension PdfPreviewCollectionViewCell: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
