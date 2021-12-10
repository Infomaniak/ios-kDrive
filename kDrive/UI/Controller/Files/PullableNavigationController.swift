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

import UIKit

class PullableNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    private var pullOriginPoint: CGPoint = .zero
    private var pullOriginSafeAreaInsets = UIEdgeInsets.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePullGesture(_:)))
        gesture.delegate = self
        view.addGestureRecognizer(gesture)
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let previewViewController = (viewControllers.last as? PreviewViewController) {
            previewViewController.dismiss(animated: true) {
                super.dismiss(animated: true, completion: completion)
            }
        } else {
            super.dismiss(animated: flag, completion: completion)
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.last as? PreviewViewController != nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGesture = otherGestureRecognizer as? UIPanGestureRecognizer {
            let velocity = panGesture.velocity(in: view)
            if abs(velocity.x) > abs(velocity.y) {
                return false
            }
        }

        if let scrollView = otherGestureRecognizer.view as? UIScrollView {
            return scrollView.contentOffset.y <= 0
        }
        return false
    }

    @objc func handlePullGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        var pullDistance: CGFloat = 0
        var targetFrame = view.frame

        switch gesture.state {
        case .began:
            pullOriginSafeAreaInsets = UIEdgeInsets(
                top: additionalSafeAreaInsets.top + view.safeAreaInsets.top,
                left: additionalSafeAreaInsets.left,
                bottom: additionalSafeAreaInsets.bottom,
                right: additionalSafeAreaInsets.right
            )
            pullOriginPoint = translation
        case .changed:
            pullDistance = translation.y - pullOriginPoint.y
            if pullDistance < 0 {
                pullDistance = 0
            } else {
                additionalSafeAreaInsets = pullOriginSafeAreaInsets
            }
            targetFrame.origin.y = pullDistance
            view.frame = targetFrame
        case .ended, .cancelled:
            pullDistance = translation.y - pullOriginPoint.y
            if pullDistance < view.frame.height / 3 {
                additionalSafeAreaInsets = UIEdgeInsets.zero
                targetFrame.origin.y = 0
                UIView.animate(withDuration: 0.2) {
                    self.view.frame = targetFrame
                }
            } else {
                dismiss(animated: true, completion: nil)
            }
        default: break
        }
    }
}
