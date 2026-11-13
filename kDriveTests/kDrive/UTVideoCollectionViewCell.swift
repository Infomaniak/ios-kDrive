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

@testable import kDrive
import kDriveCore
import Testing
import UIKit

@Suite
@MainActor
struct UTVideoCollectionViewCell {
    @Test func alignsControlsWithSheetAndUpdatesAfterResizing() throws {
        let delegate = VideoLayoutDelegate()
        delegate.panelFrame = CGRect(x: 24, y: 700, width: 352, height: 100)
        let cell = makeCell(delegate: delegate)
        let controls = try #require(cell.contentView.subviews.first { $0 is VideoControlsView })

        cell.layoutIfNeeded()
        #expect(controls.frame.minX == 24)
        #expect(controls.frame.maxX == 376)
        #expect(controls.frame.maxY == 800 - delegate.fileActionPanelHeight - UIConstants.Padding.medium)

        delegate.panelFrame = CGRect(x: 40, y: 500, width: 320, height: 300)
        cell.updateControlsLayout()
        cell.layoutIfNeeded()
        #expect(controls.frame.minX == 40)
        #expect(controls.frame.maxX == 360)
        #expect(controls.frame.maxY == 800 - delegate.fileActionPanelHeight - UIConstants.Padding.medium)
    }

    @Test(arguments: [CGFloat.zero, 75])
    func keepsControlsInsidePreviewBeforeSheetPresentation(panelHeight: CGFloat) throws {
        let delegate = VideoLayoutDelegate()
        delegate.fileActionPanelHeight = panelHeight
        let cell = makeCell(delegate: delegate)
        let controls = try #require(cell.contentView.subviews.first { $0 is VideoControlsView })

        cell.layoutIfNeeded()
        #expect(controls.frame.minX == UIConstants.Padding.medium)
        #expect(controls.frame.maxX == 400 - UIConstants.Padding.medium)
        #expect(controls.frame.maxY == 800 - panelHeight - UIConstants.Padding.medium)
    }

    @Test func doesNotExtendControlsBeyondPreviewToMatchAWiderSheet() throws {
        let delegate = VideoLayoutDelegate()
        delegate.panelFrame = CGRect(x: -200, y: 700, width: 800, height: 100)
        let cell = makeCell(delegate: delegate)
        let controls = try #require(cell.contentView.subviews.first { $0 is VideoControlsView })

        cell.layoutIfNeeded()
        #expect(controls.frame.minX == UIConstants.Padding.medium)
        #expect(controls.frame.maxX == 400 - UIConstants.Padding.medium)
    }

    @Test(arguments: [CGFloat(-400), -200, 200, 400], [CGFloat.zero, 400])
    func keepsSheetWidthWhenLayingOutAnIncomingOrOutgoingPage(pageOffset: CGFloat, contentOffset: CGFloat) throws {
        let viewport = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        viewport.bounds.origin.x = contentOffset
        let delegate = VideoLayoutDelegate()
        delegate.panelCoordinateView = viewport
        delegate.panelFrame = CGRect(x: contentOffset + 24, y: 700, width: 352, height: 100)
        let cell = makeCell(delegate: delegate)
        viewport.addSubview(cell)
        cell.frame.origin.x = contentOffset + pageOffset
        let controls = try #require(cell.contentView.subviews.first { $0 is VideoControlsView })

        cell.layoutIfNeeded()
        #expect(controls.frame.minX == 24)
        #expect(controls.frame.maxX == 376)
        #expect(controls.frame.maxY == 800 - delegate.fileActionPanelHeight - UIConstants.Padding.medium)

        cell.frame.origin.x = contentOffset
        cell.updateControlsLayout()
        cell.layoutIfNeeded()
        #expect(controls.frame.minX == 24)
        #expect(controls.frame.maxX == 376)
    }

    @Test func keepsBottomPositionWhenSheetExpandsAndCollapses() throws {
        let delegate = VideoLayoutDelegate()
        delegate.panelFrame = CGRect(x: 24, y: 700, width: 352, height: 100)
        let cell = makeCell(delegate: delegate)
        let controls = try #require(cell.contentView.subviews.first { $0 is VideoControlsView })
        cell.layoutIfNeeded()
        let previousBottom = controls.frame.maxY

        for height in [CGFloat(300), 760] {
            delegate.panelFrame = CGRect(x: 40, y: 800 - height, width: 320, height: height)
            cell.updateControlsLayout()
            cell.layoutIfNeeded()
            #expect(controls.frame.minX == 40)
            #expect(controls.frame.maxX == 360)
            #expect(controls.frame.maxY == previousBottom)
        }

        delegate.panelFrame = CGRect(x: 24, y: 700, width: 352, height: 100)
        cell.updateControlsLayout()
        cell.layoutIfNeeded()
        #expect(controls.frame.minX == 24)
        #expect(controls.frame.maxX == 376)
        #expect(controls.frame.maxY == previousBottom)
    }

    @Test(arguments: [CGFloat.zero, 200, 400], [CGFloat(300), 760])
    func keepsNewPagesAtBottomWhileSheetIsMediumOrLarge(pageOffset: CGFloat, panelHeight: CGFloat) throws {
        let viewport = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let delegate = VideoLayoutDelegate()
        delegate.panelCoordinateView = viewport
        delegate.panelFrame = CGRect(x: 24, y: 800 - panelHeight, width: 352, height: panelHeight)
        let cell = makeCell(delegate: delegate)
        viewport.addSubview(cell)
        cell.frame.origin.x = pageOffset
        let controls = try #require(cell.contentView.subviews.first { $0 is VideoControlsView })

        cell.layoutIfNeeded()
        #expect(controls.frame.minX == 24)
        #expect(controls.frame.maxX == 376)
        #expect(controls.frame.maxY == 800 - delegate.fileActionPanelHeight - UIConstants.Padding.medium)
    }

    private func makeCell(delegate: VideoLayoutDelegate) -> VideoCollectionViewCell {
        let cell = VideoCollectionViewCell(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let imageView = UIImageView(frame: cell.contentView.bounds)
        cell.contentView.addSubview(imageView)
        cell.previewFrameImageView = imageView
        cell.previewDelegate = delegate
        cell.awakeFromNib()
        return cell
    }
}

@MainActor
private final class VideoLayoutDelegate: PreviewContentCellDelegate {
    var panelFrame: CGRect?
    var panelCoordinateView: UIView?
    var fileActionPanelHeight: CGFloat = 75
    var isFullscreenPreview: Bool { false }

    func fileActionPanelFrame(in view: UIView) -> CGRect? {
        guard let panelFrame else { return nil }
        return panelCoordinateView?.convert(panelFrame, to: view) ?? panelFrame
    }

    func pdfPreviewUpdated(fileId: Int, currentPage: Int, totalPages: Int) {}
    func setFullscreen(_ fullscreen: Bool?) {}
    func errorWhilePreviewing(fileId: Int, error: Error) {}
    func openWith(from: UIView) {}
    func presentVideoPlayer(_ controller: UIViewController, completion: (() -> Void)?) {}
}
