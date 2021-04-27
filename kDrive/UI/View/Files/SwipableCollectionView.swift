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

protocol SwipeActionCollectionViewDelegate: AnyObject {
    func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath)
}

protocol SwipeActionCollectionViewDataSource: AnyObject {
    func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]?
}

class SwipableCollectionView: UICollectionView {
    private var swipeGestureRecognizer: UIPanGestureRecognizer!
    var currentlySwipedCellPath: IndexPath?
    private var currentlySwipedCell: SwipableCell?
    private var currentlySwipedCellActions: [SwipeCellAction]?
    weak var swipeDelegate: SwipeActionCollectionViewDelegate?
    weak var swipeDataSource: SwipeActionCollectionViewDataSource?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSwipeListener()
    }

    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        setupSwipeListener()
    }

    func simulateSwipe(at swipedIndexPath: IndexPath) {
        if let swipedCell = cellForItem(at: swipedIndexPath) as? SwipableCell,
            let actions = swipeDataSource?.collectionView(self, actionsFor: swipedCell, at: swipedIndexPath) {
            if currentlySwipedCellPath != swipedIndexPath {
                currentlySwipedCell?.hideSwipeActions()
                currentlySwipedCellPath = swipedIndexPath
                currentlySwipedCell = swipedCell
                currentlySwipedCellActions = actions
                addActionsForCell(actions, cell: swipedCell)
            }
            swipedCell.initialTrailingConstraintValue = swipedCell.innerViewTrailingConstraint.constant
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                swipedCell.showSwipeActions()
            }
        }
    }

    private func setupSwipeListener() {
        swipeGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didSwipe(_:)))
        swipeGestureRecognizer.delegate = self
        addGestureRecognizer(swipeGestureRecognizer)
    }

    @objc private func didSwipe(_ recognizer: UIPanGestureRecognizer) {
        let swipedIndexPath = indexPathForItem(at: recognizer.location(in: self))

        switch recognizer.state {
        case .began:
            if let swipedIndexPath = swipedIndexPath,
                let swipedCell = cellForItem(at: swipedIndexPath) as? SwipableCell,
                let actions = swipeDataSource?.collectionView(self, actionsFor: swipedCell, at: swipedIndexPath) {
                if currentlySwipedCellPath != swipedIndexPath {
                    currentlySwipedCell?.hideSwipeActions()
                    currentlySwipedCellPath = swipedIndexPath
                    currentlySwipedCell = swipedCell
                    currentlySwipedCellActions = actions
                    addActionsForCell(actions, cell: swipedCell)
                }
                swipedCell.didSwipe(recognizer)
            } else {
                resetCurrentlySelectedCell()
            }
        case .changed:
            currentlySwipedCell?.didSwipe(recognizer)
        case .ended:
            currentlySwipedCell?.didSwipe(recognizer)
            if currentlySwipedCell?.isClosed ?? true {
                resetCurrentlySelectedCell()
            }
        case .cancelled:
            currentlySwipedCell?.didSwipe(recognizer)
            if currentlySwipedCell?.isClosed ?? true {
                resetCurrentlySelectedCell()
            }
        default:
            break
        }
    }

    private func resetCurrentlySelectedCell() {
        currentlySwipedCellPath = nil
        currentlySwipedCell = nil
        currentlySwipedCellActions = nil
    }

    private func addActionsForCell(_ actions: [SwipeCellAction], cell: SwipableCell) {
        let swipeActionsView = cell.swipeActionsView!
        for (index, action) in actions.enumerated() {
            let actionButton = UIButton(frame: CGRect(x: 0, y: 0, width: swipeActionsView.frame.width, height: swipeActionsView.frame.width))
            let constraint = NSLayoutConstraint(item: actionButton, attribute: .width, relatedBy: .equal, toItem: actionButton, attribute: .height, multiplier: 1, constant: 0)
            actionButton.addConstraint(constraint)
            actionButton.backgroundColor = action.backgroundColor
            actionButton.tintColor = action.tintColor
            actionButton.setImage(action.icon, for: .normal)
            actionButton.tag = index
            actionButton.accessibilityLabel = action.title
            actionButton.addTarget(self, action: #selector(didSelectAction(_:)), for: .touchUpInside)
            swipeActionsView.addArrangedSubview(actionButton)
        }
    }

    @objc private func didSelectAction(_ sender: UIButton) {
        if let actions = currentlySwipedCellActions,
            let _ = currentlySwipedCell,
            let indexPath = currentlySwipedCellPath {
            if sender.tag < actions.count {
                let action = actions[sender.tag]
                swipeDelegate?.collectionView(self, didSelect: action, at: indexPath)
                switch action.style {
                case .normal:
                    currentlySwipedCell?.hideSwipeActions()
                    resetCurrentlySelectedCell()
                case .destructive:
                    resetCurrentlySelectedCell()
                case .stayOpen:
                    break
                }
            }
        }
    }
}
//MARK: - UIGestureRecognizerDelegate
extension SwipableCollectionView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
            gestureRecognizer === swipeGestureRecognizer {
            let velocity = gestureRecognizer.velocity(in: self)
            if abs(velocity.y) > abs(velocity.x) {
                currentlySwipedCell?.hideSwipeActions()
                return false
            }

            let swipeLocation = gestureRecognizer.location(in: self)

            if let _ = indexPathForItem(at: swipeLocation) {
                return true
            } else {
                return false
            }
        } else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }
}
