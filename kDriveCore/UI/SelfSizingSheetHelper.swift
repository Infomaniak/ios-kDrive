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

import UIKit

public class SelfSizingSheetHelper {
    private weak var viewController: UIViewController?
    private weak var scrollView: UIScrollView?

    private var contentSizeObservation: NSKeyValueObservation?

    public init(
        viewController: UIViewController,
        scrollView: UIScrollView,
        showsGrabber: Bool = true
    ) {
        self.viewController = viewController
        self.scrollView = scrollView

        guard let sheet = viewController.sheetPresentationController else {
            return
        }

        viewController.modalPresentationStyle = .pageSheet
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        sheet.prefersEdgeAttachedInCompactHeight = true
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        sheet.prefersGrabberVisible = showsGrabber

        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .old]) { _, _ in
            let totalPanelContentHeight = scrollView.contentSize.height

            let newHeightDetent = UISheetPresentationController.Detent
                .custom(identifier: .init("h-\(totalPanelContentHeight)")) { _ in
                    totalPanelContentHeight
                }

            guard sheet.selectedDetentIdentifier != newHeightDetent.identifier else { return }

            scrollView.isScrollEnabled = totalPanelContentHeight > (scrollView.window?.bounds.height ?? 0)
            sheet.detents = [newHeightDetent]
            sheet.selectedDetentIdentifier = newHeightDetent.identifier
        }
    }
}
