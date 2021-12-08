//
//  SNViewPullable.swift
//  SNViewPullable
//
//  MIT License
//
//  Copyright (c) 2018 Sean Choi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import UIKit

public protocol SNViewPullable: UIGestureRecognizerDelegate {
    var pullableOriginPoint: CGPoint { get set }
    var pullableOriginSafeAreaInsets: UIEdgeInsets { get set }
    var pullableMaxDistance: CGFloat { get }

    var viewAnimationDuration: TimeInterval { get }

    func addViewPullablePanGesture()
    func handleViewPullablePanGesture(_ gesture: UIPanGestureRecognizer)

    func viewPullingBegin()
    func viewPullingMoved()
    func viewPullingCancel()
    func viewPullingWillEnd()
    func viewPullingDidEnd()
}

// MARK: stub

public extension SNViewPullable {
    func viewPullingBegin() {}
    func viewPullingMoved() {}
    func viewPullingCancel() {}
    func viewPullingWillEnd() {}
    func viewPullingDidEnd() {}
}

// MARK: Pull Gestures

public extension SNViewPullable where Self: UIViewController {
    func addViewPullablePanGesture() {
        let gesture = UIPanGestureRecognizer(target: self, action: .swipePangesture)
        gesture.delegate = self
        view.addGestureRecognizer(gesture)
    }

    func handleViewPullablePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        var pulledDistance: CGFloat = 0
        var targetFrame = view.frame

        switch gesture.state {
        case .began:
            pullableOriginPoint = translation
            if #available(iOS 11.0, *) {
                self.pullableOriginSafeAreaInsets = UIEdgeInsets(
                    top: self.additionalSafeAreaInsets.top + self.view.safeAreaInsets.top,
                    left: self.additionalSafeAreaInsets.left,
                    bottom: self.additionalSafeAreaInsets.bottom,
                    right: self.additionalSafeAreaInsets.right
                )
            }
            self.viewPullingBegin()
        case .changed:
            self.additionalSafeAreaInsets = self.pullableOriginSafeAreaInsets

            pulledDistance = translation.y - pullableOriginPoint.y
            if pulledDistance < 0 {
                pulledDistance = 0
            }
            targetFrame.origin.y = pulledDistance
            view.frame = targetFrame
            self.viewPullingMoved()
        case .ended, .cancelled:
            pulledDistance = translation.y - pullableOriginPoint.y
            if pulledDistance < pullableMaxDistance {
                self.additionalSafeAreaInsets = UIEdgeInsets(
                    top: self.additionalSafeAreaInsets.top - self.view.safeAreaInsets.top,
                    left: self.additionalSafeAreaInsets.left,
                    bottom: self.additionalSafeAreaInsets.bottom,
                    right: self.additionalSafeAreaInsets.right
                )

                targetFrame.origin.y = 0
                UIView.animate(withDuration: viewAnimationDuration) {
                    self.view.frame = targetFrame
                }
                self.viewPullingCancel()
            } else {
                self.viewPullingWillEnd()
                dismiss(animated: true, completion: nil)
                self.viewPullingDidEnd()
            }
        default: break
        }
    }
}

// MARK: Private extensions

private extension UIViewController {
    @objc func _handleViewPullablePanGesture(_ gesture: UIPanGestureRecognizer) {
        if let pullable = self as? SNViewPullable {
            pullable.handleViewPullablePanGesture(gesture)
        }
    }
}

private extension Selector {
    static let swipePangesture =
        #selector(UIViewController._handleViewPullablePanGesture(_:))
}
