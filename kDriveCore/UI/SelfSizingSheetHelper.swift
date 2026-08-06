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

import DesignSystem
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

        viewController.modalPresentationStyle = .pageSheet
        guard let sheet = viewController.sheetPresentationController else {
            return
        }

        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        sheet.prefersEdgeAttachedInCompactHeight = true
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        sheet.prefersGrabberVisible = showsGrabber

        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .old]) { [weak scrollView,
                                                                                             weak sheet] _, _ in
                guard let scrollView, let sheet else { return }

                var totalPanelContentHeight = scrollView.contentSize.height
                if UIDevice.current.userInterfaceIdiom != .pad && totalPanelContentHeight > 80 {
                    scrollView.contentInset.top = IKPadding.medium
                    totalPanelContentHeight += scrollView.contentInset.top
                }

                let newHeightDetent = UISheetPresentationController.Detent
                    .custom(identifier: .init("h-\(totalPanelContentHeight)")) { _ in
                        totalPanelContentHeight
                    }

                guard sheet.selectedDetentIdentifier != newHeightDetent.identifier else { return }

                scrollView.isScrollEnabled = true
                sheet.detents = [newHeightDetent]
                sheet.selectedDetentIdentifier = newHeightDetent.identifier
        }
    }
}
