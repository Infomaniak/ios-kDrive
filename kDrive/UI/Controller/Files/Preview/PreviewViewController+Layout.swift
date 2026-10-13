/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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

extension PreviewViewController {
    func updatePreviewViewPort() {
        let respectsLeadingSafeArea = traitCollection.horizontalSizeClass == .regular
        let collectionViewLeadingConstraint = view.constraints.first {
            $0.firstItem === collectionView && $0.firstAttribute == .leading
        }

        var leftConstraint = view.safeAreaInsets.left
        let availableBounds = view.bounds.inset(by: UIEdgeInsets(
            top: 0,
            left: leftConstraint,
            bottom: 0,
            right: 0
        ))

        isBookPreviewLayout = false

        let referenceView: UIView = splitViewController?.view ?? view

        if #available(iOS 27.1, *) {
            let division = referenceView.reservedRegions(kind: .division).first { region in
                let frame = region.frame
                return region.isActive && frame.width > 0 && frame.height > frame.width
            }

            if let division {
                let frame = referenceView.convert(division.frame, to: view)
                let spansDivision = frame.intersects(availableBounds)
                && frame.minX > availableBounds.minX
                && frame.maxX < availableBounds.maxX

                isBookPreviewLayout = spansDivision && !isSidebarVisible

                leftConstraint = frame.midX - view.bounds.minX
            }
        }

        guard let collectionViewLeadingConstraint else { return }

        let targetInset = respectsLeadingSafeArea ? leftConstraint : 0

        if collectionViewLeadingConstraint.constant != targetInset {
            indexBeforeBoundsChange = indexBeforeBoundsChange ?? currentIndex
            collectionViewLeadingConstraint.constant = targetInset
        }
    }

    func scheduleFileActionsLayoutUpdate() {
        guard !isFileActionsLayoutUpdateScheduled else { return }
        isFileActionsLayoutUpdateScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            defer { self.isFileActionsLayoutUpdateScheduled = false }

            guard self.viewIfLoaded?.window != nil,
                  let panel = self.fileInformationsViewController,
                  !panel.isBeingDismissed else { return }

            self.view.layoutIfNeeded()

            let enteredBookLayout =
                self.lastAppliedBookPreviewLayout == false && self.isBookPreviewLayout

            self.lastAppliedBookPreviewLayout = self.isBookPreviewLayout

            if !self.isBookPreviewLayout, self.navigationItem.hidesBackButton {
                self.navigationItem.setHidesBackButton(false, animated: true)
            }

            if enteredBookLayout {
                self.setFullscreen(false)
            }

            guard panel.presentingViewController != nil else { return }
            self.updateSheetContainerFrameIfNeeded(animated: true)
        }
    }

    func updateSheetContainerFrameIfNeeded(animated: Bool = false) {
        guard !isUpdatingSheetContainer,
              let sheet = fileInformationsViewController?.sheetPresentationController
        else { return }

        isUpdatingSheetContainer = true
        defer { isUpdatingSheetContainer = false }

        var targetFrame: CGRect?
        if traitCollection.horizontalSizeClass == .regular,
           let containerView = sheet.containerView,
           let containerSuperview = containerView.superview {
            let layoutView: UIView = isBookPreviewLayout ? view : collectionView
            let frame = layoutView.convert(
                layoutView.bounds,
                to: containerSuperview
            )

            if !frame.isEmpty, containerView.frame != frame {
                targetFrame = frame
            }
        }

        var updatePlacement: (() -> Void)?
        if #available(iOS 27.1, *) {
            let placement: UISheetPresentationController.Placement
            if isBookPreviewLayout {
                placement = view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .trailing : .leading
            } else {
                placement = .automatic
            }
            if sheet.preferredPlacement != placement {
                updatePlacement = {
                    sheet.preferredPlacement = placement
                    sheet.detents = self.fileActionsDetents
                }
            }
        }

        guard targetFrame != nil || updatePlacement != nil else { return }


        let changes: () -> Void = {
            if let targetFrame {
                sheet.containerView?.frame = targetFrame
            }
            updatePlacement?()
            sheet.containerView?.setNeedsLayout()
            sheet.containerView?.layoutIfNeeded()
        }

        if animated,
           fileInformationsViewController.presentingViewController != nil,
           !fileInformationsViewController.isBeingPresented {
            sheet.animateChanges(changes)
        } else {
            UIView.performWithoutAnimation(changes)
        }
    }
}
