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
        previewLayout = .standard

        guard let leadingConstraint = view.constraints.first(where: {
            $0.isActive
                && $0.firstItem === collectionView
                && ($0.firstAttribute == .leading || $0.firstAttribute == .left)
        }),
            let bottomConstraint = view.constraints.first(where: {
                $0.isActive
                    && $0.firstItem === view
                    && $0.firstAttribute == .bottom
                    && $0.secondItem === collectionView
                    && $0.secondAttribute == .bottom
            }) else { return }

        let respectsSafeArea = traitCollection.horizontalSizeClass == .regular
        var leadingInset = respectsSafeArea ? view.safeAreaInsets.left : 0
        var bottomInset = 0.0

        if #available(iOS 27.1, *) {
            let referenceView: UIView = splitViewController?.view ?? view
            let availableBounds = view.bounds.inset(by: view.safeAreaInsets)

            _ = referenceView.reservedRegions(kind: .division).first { region in
                guard region.isActive else { return false }
                let frame = referenceView.convert(region.frame, to: view)

                guard !frame.isEmpty, frame.intersects(availableBounds) else { return false }

                if let inset = landscapePreviewInset(for: frame, in: availableBounds) {
                    leadingInset = inset
                } else if let inset = portraitPreviewInset(for: frame, in: availableBounds) {
                    bottomInset = inset
                } else {
                    return false
                }

                return true
            }
        }

        updatePreviewConstraint(leadingConstraint, constant: leadingInset)
        updatePreviewConstraint(bottomConstraint, constant: bottomInset)
    }

    private func updatePreviewConstraint(
        _ constraint: NSLayoutConstraint,
        constant: CGFloat
    ) {
        guard constraint.constant != constant else { return }

        indexBeforeBoundsChange = indexBeforeBoundsChange ?? currentIndex
        constraint.constant = constant
    }

    private func landscapePreviewInset(
        for divisionFrame: CGRect,
        in availableBounds: CGRect
    ) -> CGFloat? {
        guard divisionFrame.height > divisionFrame.width else { return nil }

        let spansDivision = divisionFrame.intersects(availableBounds)
            && divisionFrame.minX > availableBounds.minX
            && divisionFrame.maxX < availableBounds.maxX

        previewLayout = spansDivision && !isSidebarVisible ? .sideBySide : .standard

        return divisionFrame.midX - view.bounds.minX
    }

    private func portraitPreviewInset(
        for divisionFrame: CGRect,
        in availableBounds: CGRect
    ) -> CGFloat? {
        guard divisionFrame.width > divisionFrame.height else { return nil }

        let spansDivision = divisionFrame.intersects(availableBounds)
            && divisionFrame.minY > availableBounds.minY
            && divisionFrame.maxY < availableBounds.maxY

        previewLayout = spansDivision && !isSidebarVisible ? .stacked : .standard

        return divisionFrame.midY - view.bounds.minY
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
            let detents = fileActionsDetents
            let canExpand = presentationOrigin != .activities
            let undimmedIdentifier: UISheetPresentationController.Detent.Identifier =
                canExpand && previewLayout != .stacked ? .large : .medium

            if sheet.preferredPlacement != placement
                || sheet.detents.map(\.identifier) != detents.map(\.identifier)
                || sheet.largestUndimmedDetentIdentifier != undimmedIdentifier {
                updatePlacement = {
                    sheet.preferredPlacement = placement
                    sheet.detents = detents
                    sheet.largestUndimmedDetentIdentifier = undimmedIdentifier
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
