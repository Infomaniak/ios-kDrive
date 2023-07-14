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

class SwipeCellAction: Equatable {
    var identifier: String
    var title: String
    var backgroundColor: UIColor
    var tintColor: UIColor
    var icon: UIImage
    var style: SwipeActionStyle

    enum SwipeActionStyle {
        case normal
        case stayOpen
        case destructive
    }

    init(
        identifier: String,
        title: String,
        backgroundColor: UIColor,
        tintColor: UIColor = .white,
        icon: UIImage,
        style: SwipeActionStyle = .normal
    ) {
        self.identifier = identifier
        self.title = title
        self.backgroundColor = backgroundColor
        self.tintColor = tintColor
        self.icon = icon
        self.style = style
    }

    static func == (lhs: SwipeCellAction, rhs: SwipeCellAction) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

protocol SwipableCell: UICollectionViewCell {
    var swipeStartPoint: CGPoint { get set }
    var isClosed: Bool { get }
    var initialTrailingConstraintValue: CGFloat { get set }
    var contentInsetView: UIView! { get set }
    var swipeActionsView: UIStackView? { get set }
    var innerViewTrailingConstraint: NSLayoutConstraint! { get set }
    var innerViewLeadingConstraint: NSLayoutConstraint! { get set }
    func didSwipe(_ recognizer: UIPanGestureRecognizer)
    func hideSwipeActions()
    func showSwipeActions()
    func resetSwipeActions()
}

// MARK: SwipableCell default implementation

extension SwipableCell {
    private var closeThreshold: CGFloat {
        return swipeActionsSize / 4
    }

    private var openThreshold: CGFloat {
        return swipeActionsSize / 3
    }

    private var swipeActionsSize: CGFloat {
        return swipeActionsView?.bounds.width ?? 0
    }

    var isClosed: Bool {
        return innerViewLeadingConstraint.constant == 0
    }

    private func updateConstraintsWithAnimationIfNeeded(animated: Bool, completion: @escaping ((Bool) -> Void)) {
        let duration = animated ? 0.1 : 0
        UIView.animate(withDuration: duration, animations: {
            self.contentInsetView.layoutIfNeeded()
        }, completion: completion)
    }

    func didSwipe(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            swipeStartPoint = recognizer.translation(in: contentInsetView)
            initialTrailingConstraintValue = innerViewTrailingConstraint.constant
        case .changed:
            let currentPoint = recognizer.translation(in: contentInsetView)
            let delta = currentPoint.x - swipeStartPoint.x
            let panningLeft = currentPoint.x < swipeStartPoint.x
            if initialTrailingConstraintValue == 0 {
                if !panningLeft {
                    let maxDelta = max(-delta, 0)
                    if maxDelta == 0 {
                        hideSwipeActions()
                    } else {
                        innerViewTrailingConstraint.constant = maxDelta
                    }
                } else {
                    let minDelta = min(-delta, swipeActionsSize)
                    if minDelta == swipeActionsSize {
                        showSwipeActions()
                    } else {
                        innerViewTrailingConstraint.constant = minDelta
                    }
                }
            } else {
                let adjustedDelta = initialTrailingConstraintValue - delta
                if !panningLeft {
                    let maxDelta = max(adjustedDelta, 0)
                    if max(adjustedDelta, 0) == 0 {
                        hideSwipeActions()
                    } else {
                        innerViewTrailingConstraint.constant = maxDelta
                    }
                } else {
                    let minDelta = min(adjustedDelta, swipeActionsSize)
                    if minDelta == swipeActionsSize {
                        showSwipeActions()
                    } else {
                        innerViewTrailingConstraint.constant = minDelta
                    }
                }
            }
            innerViewLeadingConstraint.constant = -innerViewTrailingConstraint.constant
        case .ended:
            if initialTrailingConstraintValue == 0 && innerViewTrailingConstraint.constant >= openThreshold {
                showSwipeActions()
            } else if innerViewTrailingConstraint.constant >= swipeActionsSize - closeThreshold {
                showSwipeActions()
            } else {
                hideSwipeActions()
            }
        case .cancelled:
            if initialTrailingConstraintValue == 0 {
                hideSwipeActions()
            } else {
                showSwipeActions()
            }
        default:
            break
        }
    }

    func hideSwipeActions() {
        innerViewTrailingConstraint.constant = 0
        innerViewLeadingConstraint.constant = 0
        updateConstraintsWithAnimationIfNeeded(animated: true) { _ in
            self.innerViewTrailingConstraint.constant = 0
            self.innerViewLeadingConstraint.constant = 0
            self.resetSwipeActions()
        }
    }

    func showSwipeActions() {
        if initialTrailingConstraintValue == swipeActionsSize && innerViewTrailingConstraint.constant == swipeActionsSize {
            return
        }

        innerViewTrailingConstraint.constant = swipeActionsSize
        innerViewLeadingConstraint.constant = -innerViewTrailingConstraint.constant
        updateConstraintsWithAnimationIfNeeded(animated: true) { _ in
            self.innerViewTrailingConstraint.constant = self.swipeActionsSize
            self.innerViewLeadingConstraint.constant = -self.innerViewTrailingConstraint.constant
        }
    }

    func resetSwipeActions() {
        for view in swipeActionsView?.arrangedSubviews ?? [] {
            view.removeFromSuperview()
        }
        innerViewTrailingConstraint?.constant = 0
        innerViewLeadingConstraint?.constant = 0
        swipeStartPoint = .zero
        initialTrailingConstraintValue = 0
    }
}
