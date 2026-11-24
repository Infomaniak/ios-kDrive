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
import UIKit

class PreviewCollectionViewCell: UICollectionViewCell {
    var tapGestureRecognizer: UITapGestureRecognizer!
    weak var previewDelegate: PreviewContentCellDelegate?

    var controlsLeftConstraint: NSLayoutConstraint?
    var controlsRightConstraint: NSLayoutConstraint?
    var controlsBottomConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTapGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }

    private func setupTapGesture() {
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOnCell))
        addGestureRecognizer(tapGestureRecognizer)
    }

    @objc func didTapOnCell() {
        previewDelegate?.setFullscreen(nil)
    }

    var prefersFullscreenPreview: Bool {
        false
    }

    func configureWith(file: File) {
        // META: keep SonarCloud happy
    }

    func didStartDisplaying() {
        // META: keep SonarCloud happy
    }

    func didEndDisplaying() {
        // META: keep SonarCloud happy
    }

    func didLeavePage() {
        // META: keep SonarCloud happy
    }

    func fullscreenDidChange() {
        // META: keep SonarCloud happy
    }

    func willDisplayInCollectionView() {
        // META: keep SonarCloud happy
    }

    func updateControlsLayout() {
        guard controlsLeftConstraint != nil || controlsRightConstraint != nil || controlsBottomConstraint != nil
        else { return }

        let spacing = UIConstants.Padding.medium
        let safeFrame = safeAreaLayoutGuide.layoutFrame
        var leftInset = safeFrame.minX - bounds.minX + spacing
        var rightInset = bounds.maxX - safeFrame.maxX + spacing

        let viewport = superview ?? self
        if let panelFrame = previewDelegate?.fileActionPanelFrame(in: viewport),
           panelFrame.intersects(viewport.bounds),
           panelFrame.minX >= viewport.bounds.minX,
           panelFrame.maxX <= viewport.bounds.maxX {
            // Each page keeps the viewport's horizontal alignment while moving during a swipe.
            leftInset = panelFrame.minX - viewport.bounds.minX
            rightInset = viewport.bounds.maxX - panelFrame.maxX
        }

        let bottom = safeFrame.maxY - (previewDelegate?.fileActionPanelHeight ?? 0) - spacing
        controlsLeftConstraint?.constant = leftInset
        controlsRightConstraint?.constant = -rightInset
        controlsBottomConstraint?.constant = bottom - bounds.maxY
    }

    func didEndDisplayingInCollectionView() {
        // META: keep SonarCloud happy
    }
}
