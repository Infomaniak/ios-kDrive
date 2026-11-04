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

import kDriveCore
import kDriveResources
import PDFKit
import UIKit

class PdfPreviewCollectionViewCell: PreviewCollectionViewCell, UIScrollViewDelegate {
    @IBOutlet var pdfPreview: PDFView!
    private var documentUrl: URL?
    private var fileId: Int?
    private var configurationId = UUID()
    private var activationTask: Task<Void, Never>?
    private var isDisplaying = false
    private var hasActivatedDocument = false
    var breadcrumbContext: PreviewBreadcrumb.CellContext?
    private let breadcrumbCellId = UUID().uuidString

    private func recordBreadcrumb(_ message: String) {
        var metadata: [String: Any] = [
            "cellId": breadcrumbCellId,
            "configurationId": configurationId.uuidString,
            "isDisplaying": isDisplaying,
            "activationPending": activationTask != nil,
            "hasActivatedDocument": hasActivatedDocument,
            "hasDocument": pdfPreview.document != nil
        ]
        metadata["sessionId"] = breadcrumbContext?.sessionId
        metadata["item"] = breadcrumbContext?.item
        PreviewBreadcrumb.record(message, metadata: metadata)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        pdfPreview.autoScales = true
        pdfPreview.enableDataDetectors = true
        pdfPreview.interpolationQuality = .none
        pdfPreview.backgroundColor = KDriveResourcesAsset.previewBackgroundColor.color
    }

    @objc private func pageChanged() {
        let configurationId = configurationId
        Task { @MainActor [weak self] in
            guard let self, self.configurationId == configurationId, self.isDisplaying,
                  let fileId = self.fileId,
                  let document = self.pdfPreview.document,
                  let page = self.pdfPreview.currentPage else { return }
            let pageIndex = document.index(for: page)
            guard pageIndex != NSNotFound else { return }
            self.previewDelegate?.pdfPreviewUpdated(
                fileId: fileId,
                currentPage: pageIndex + 1,
                totalPages: document.pageCount
            )
        }
    }

    override func configureWith(file: File) {
        configureWith(documentUrl: file.localUrl, fileId: file.id)
    }

    func configureWith(documentUrl: URL, fileId: Int) {
        self.documentUrl = documentUrl
        self.fileId = fileId
        configurationId = UUID()
        recordBreadcrumb("pdf.configured")
    }

    override func willDisplayInCollectionView() {
        isDisplaying = true
        recordBreadcrumb("pdf.display.begin")
        guard !hasActivatedDocument, activationTask == nil else { return }

        let configurationId = configurationId
        // PDFKit can force layout. Activate only after UIKit has finished provisioning and displaying the cell.
        activationTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled, self.configurationId == configurationId, self.isDisplaying,
                  let documentUrl = self.documentUrl else { return }
            self.activationTask = nil
            self.hasActivatedDocument = true
            self.observePageChanges()
            self.recordBreadcrumb("pdf.activation.begin")
            self.pdfPreview.document = PDFDocument(url: documentUrl)
            self.recordBreadcrumb("pdf.activation.end")
            self.pageChanged()
        }
    }

    override func didEndDisplayingInCollectionView() {
        recordBreadcrumb("pdf.display.end")
        isDisplaying = false
        activationTask?.cancel()
        activationTask = nil
    }

    private func observePageChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pageChanged),
            name: .PDFViewPageChanged,
            object: pdfPreview
        )
    }

    override func prepareForReuse() {
        recordBreadcrumb("pdf.reuse.begin")
        super.prepareForReuse()
        didEndDisplayingInCollectionView()
        configurationId = UUID()
        NotificationCenter.default.removeObserver(self, name: .PDFViewPageChanged, object: pdfPreview)
        pdfPreview.document = nil
        documentUrl = nil
        fileId = nil
        hasActivatedDocument = false
        previewDelegate = nil
        breadcrumbContext = nil
    }
}
