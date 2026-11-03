/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation
@testable import kDrive
import PDFKit
import Testing
import UIKit

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct UTPdfPreviewCollectionViewCell {
    @Test func configuresWithoutActivatingPDFKit() {
        let cell = PdfPreviewCollectionViewCell(frame: .zero)
        let pdfView = PDFView()
        cell.pdfPreview = pdfView
        cell.configureWith(documentUrl: URL(fileURLWithPath: "/unused.pdf"))
        #expect(pdfView.document == nil)
    }

    @Test func activatesAfterDisplayAndCancelsActivationOnReuse() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300)).pdfData { context in
            context.beginPage()
        }
        try data.write(to: url)

        let cell = PdfPreviewCollectionViewCell(frame: .zero)
        let pdfView = PDFView(frame: CGRect(x: 0, y: 0, width: 200, height: 300))
        cell.pdfPreview = pdfView
        cell.configureWith(documentUrl: url)
        cell.willDisplayInCollectionView()
        #expect(pdfView.document == nil)
        cell.prepareForReuse()
        await Task { @MainActor in }.value
        #expect(pdfView.document == nil)

        cell.configureWith(documentUrl: url)
        let documents = AsyncStream<Void>.makeStream()
        let observation = pdfView.observe(\.document, options: [.new]) { _, change in
            if change.newValue ?? nil != nil {
                documents.continuation.yield(())
            }
        }
        defer { observation.invalidate() }
        cell.willDisplayInCollectionView()
        var iterator = documents.stream.makeAsyncIterator()
        _ = await iterator.next()
        let document = pdfView.document
        #expect(document?.pageCount == 1)
        #expect(pdfView.document === document)

        cell.didEndDisplayingInCollectionView()
        cell.willDisplayInCollectionView()
        #expect(pdfView.document === document)
        cell.prepareForReuse()
        #expect(pdfView.document == nil)
    }
}
