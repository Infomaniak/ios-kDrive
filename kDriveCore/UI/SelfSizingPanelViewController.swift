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
import UIKit

public class SelfSizingPanelViewController: UIViewController {
    private let contentViewController: UIViewController
    private let scrollView = UIScrollView()

    private var contentSizeObservation: NSKeyValueObservation?

    public init(contentViewController: UIViewController, backgroundColor: UIColor = .systemBackground) {
        self.contentViewController = contentViewController
        scrollView.backgroundColor = backgroundColor
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadView() {
        view = scrollView
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        if let sheetPresentationController {
            sheetPresentationController.prefersScrollingExpandsWhenScrolledToEdge = false
            sheetPresentationController.prefersEdgeAttachedInCompactHeight = true
            sheetPresentationController.widthFollowsPreferredContentSizeWhenEdgeAttached = true
            sheetPresentationController.prefersGrabberVisible = true

            setupScrollViewObservation(sheetPresentationController: sheetPresentationController)
        }

        embedContentViewController()
    }

    private func setupScrollViewObservation(sheetPresentationController: UISheetPresentationController) {
        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .old]) { [weak self] _, _ in
            guard let self else { return }

            let totalPanelContentHeight = scrollView.contentSize.height

            let newHeightDetent = UISheetPresentationController.Detent
                .custom(identifier: .init("h-\(totalPanelContentHeight)")) { _ in
                    totalPanelContentHeight
                }

            guard sheetPresentationController.selectedDetentIdentifier != newHeightDetent.identifier else { return }

            scrollView.isScrollEnabled = totalPanelContentHeight > (scrollView.window?.bounds.height ?? 0)
            sheetPresentationController.detents = [newHeightDetent]
            sheetPresentationController.selectedDetentIdentifier = newHeightDetent.identifier
        }
    }

    private func embedContentViewController() {
        addChild(contentViewController)

        guard let contentView = contentViewController.view else { return }

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        contentViewController.didMove(toParent: self)
    }
}
