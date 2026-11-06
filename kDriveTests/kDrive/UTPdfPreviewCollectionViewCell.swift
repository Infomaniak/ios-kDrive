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
        cell.configureWith(documentUrl: URL(fileURLWithPath: "/unused.pdf"), fileId: 1)
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
        cell.configureWith(documentUrl: url, fileId: 1)
        cell.willDisplayInCollectionView()
        #expect(pdfView.document == nil)
        cell.prepareForReuse()
        await Task { @MainActor in }.value
        #expect(pdfView.document == nil)

        cell.configureWith(documentUrl: url, fileId: 2)
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

    @Test func reportsPageCountsAndIgnoresQueuedUpdatesAfterReuse() async throws {
        let cell = PdfPreviewCollectionViewCell(frame: .zero)
        let pdfView = PDFView(frame: CGRect(x: 0, y: 0, width: 200, height: 300))
        cell.pdfPreview = pdfView
        let delegate = PDFPageDelegate()
        let data = UIGraphicsPDFRenderer(bounds: pdfView.bounds).pdfData { context in
            context.beginPage()
            context.beginPage()
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        cell.configureWith(documentUrl: url, fileId: 42)
        cell.previewDelegate = delegate
        cell.willDisplayInCollectionView()
        var updates = delegate.updates.stream.makeAsyncIterator()
        let initialUpdate = await updates.next()
        #expect(initialUpdate?.fileId == 42)
        #expect(initialUpdate?.currentPage == 1)
        #expect(initialUpdate?.totalPages == 2)
        let document = try #require(pdfView.document)
        try pdfView.go(to: #require(document.page(at: 1)))
        NotificationCenter.default.post(name: .PDFViewPageChanged, object: pdfView)

        var update = await updates.next()
        while update?.currentPage == 1 {
            update = await updates.next()
        }
        #expect(update?.fileId == 42)
        #expect(update?.currentPage == 2)
        #expect(update?.totalPages == 2)

        NotificationCenter.default.post(name: .PDFViewPageChanged, object: pdfView)
        cell.prepareForReuse()
        let updateCount = delegate.updateCount
        await Task { @MainActor in }.value
        #expect(delegate.updateCount == updateCount)
    }
}

@MainActor
private final class PDFPageDelegate: PreviewContentCellDelegate {
    struct PageUpdate: Sendable {
        let fileId: Int
        let currentPage: Int
        let totalPages: Int
    }

    let updates = AsyncStream<PageUpdate>.makeStream()
    private(set) var updateCount = 0
    var fileActionPanelHeight: CGFloat { 0 }
    var isFullscreenPreview: Bool { true }

    func pdfPreviewUpdated(fileId: Int, currentPage: Int, totalPages: Int) {
        updateCount += 1
        updates.continuation.yield(PageUpdate(fileId: fileId, currentPage: currentPage, totalPages: totalPages))
    }

    func setFullscreen(_ fullscreen: Bool?) {}
    func setPlaybackFullscreen(_ isPlaying: Bool) {}
    func errorWhilePreviewing(fileId: Int, error: Error) {}
    func openWith(from: UIView) {}
    func presentVideoPlayer(_ controller: UIViewController, completion: (() -> Void)?) {}
}
