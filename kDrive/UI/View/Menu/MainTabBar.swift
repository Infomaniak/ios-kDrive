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

import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

/// Delegation from MainTabBar towards MainTabViewController
protocol MainTabBarDelegate: AnyObject {
    func plusButtonPressed()
    func avatarLongTouch()
    func avatarDoubleTap()
}

final class MainTabBar: UITabBar {
    override var backgroundColor: UIColor? {
        get {
            return fillColor
        }
        set {
            fillColor = newValue
            setNeedsDisplay()
        }
    }

    private var fillColor: UIColor!

    var centerButton: IKRoundButton!

    private let extraHeight = 7.0
    private let offsetY = -3.0
    private var tabBarHeight: CGFloat {
        return frame.height - safeAreaInsets.bottom + extraHeight
    }

    private var shapeLayer: CALayer?
    private var backgroundLayer: CALayer?

    weak var tabDelegate: MainTabBarDelegate?

    override func draw(_ rect: CGRect) {
        addShape()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
    }

    private func addShape() {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = createPath()
        shapeLayer.fillColor = backgroundColor?.cgColor
        shapeLayer.lineWidth = 0.5

        if let oldShapeLayer = self.shapeLayer {
            layer.replaceSublayer(oldShapeLayer, with: shapeLayer)
        } else {
            layer.insertSublayer(shapeLayer, at: 0)
        }
        self.shapeLayer = shapeLayer
        setupBackgroundGradient()
        setupMiddleButton()
        setupGestureRecognizer()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = createPath()
        addShadow()
    }

    func createPath() -> CGPath {
        let buttonRadius = tabBarHeight / 2
        let buttonMargin = 8.0
        let path = UIBezierPath()
        let centerWidth = frame.width / 2

        path.move(to: CGPoint(x: 45, y: 0))
        path.addArc(withCenter: CGPoint(x: centerWidth - (buttonRadius + buttonMargin + 3), y: 3),
                    radius: 3,
                    startAngle: 270 * Double.pi / 180, endAngle: 0 * Double.pi / 180,
                    clockwise: true)
        path.addArc(withCenter: CGPoint(x: centerWidth, y: 10),
                    radius: buttonRadius + buttonMargin + 10 > tabBarHeight ? tabBarHeight - 10 : buttonRadius + buttonMargin,
                    startAngle: 180 * Double.pi / 180, endAngle: 0 * Double.pi / 180,
                    clockwise: false)
        path.addArc(withCenter: CGPoint(x: centerWidth + (buttonRadius + buttonMargin + 3), y: 3),
                    radius: 3,
                    startAngle: 180 * Double.pi / 180, endAngle: 270 * Double.pi / 180,
                    clockwise: true)
        path.addArc(withCenter: CGPoint(x: frame.width - 40, y: tabBarHeight / 2),
                    radius: tabBarHeight / 2,
                    startAngle: 270 * Double.pi / 180, endAngle: 90 * Double.pi / 180,
                    clockwise: true)
        path.addArc(withCenter: CGPoint(x: 40, y: tabBarHeight / 2), radius: tabBarHeight / 2,
                    startAngle: 90 * Double.pi / 180, endAngle: 270 * Double.pi / 180,
                    clockwise: true)
        path.close()
        path.apply(CGAffineTransform(translationX: 0, y: offsetY))
        return path.cgPath
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if bounds.contains(point) || (centerButton != nil && centerButton.frame.contains(point)) {
            return true
        } else {
            return false
        }
    }

    private func setupBackgroundGradient() {
        let gradient = CAGradientLayer()
        let height = 120.0
        let inset = (superview?.frame.height ?? 0) - frame.height - frame.minY
        gradient.frame = CGRect(x: 0, y: bounds.height + inset - height, width: bounds.width, height: height)
        gradient.colors = [
            KDriveResourcesAsset.backgroundColor.color.withAlphaComponent(0).cgColor,
            KDriveResourcesAsset.backgroundColor.color.cgColor
        ]
        if let oldBackgroundLayer = backgroundLayer {
            layer.replaceSublayer(oldBackgroundLayer, with: gradient)
        } else {
            layer.insertSublayer(gradient, at: 0)
        }
        backgroundLayer = gradient
    }

    private func setupMiddleButton() {
        let oldButton = centerButton
        let originY = tabBarHeight * -18 / 60 + offsetY
        if centerButton?.superview != nil {
            centerButton.removeFromSuperview()
        }
        centerButton = IKRoundButton(frame: CGRect(
            x: (bounds.width / 2) - (tabBarHeight / 2),
            y: originY,
            width: tabBarHeight,
            height: tabBarHeight
        ))
        centerButton.setTitle("", for: .normal)
        centerButton.setImage(KDriveResourcesAsset.plus.image, for: .normal)
        centerButton.imageEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        centerButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonAdd
        // Keep old button property
        centerButton.isEnabled = oldButton?.isEnabled ?? true
        // Shadow
        centerButton.layer.shadowPath = UIBezierPath(ovalIn: centerButton.bounds).cgPath
        centerButton.elevated = true
        centerButton.elevation = 16
        addSubview(centerButton)
        centerButton.addTarget(self, action: #selector(centerButtonAction), for: .touchUpInside)
    }

    private func setupGestureRecognizer() {
        let longTouch = UILongPressGestureRecognizer(target: self,
                                                     action: #selector(Self.handleLongTouch(recognizer:)))
        addGestureRecognizer(longTouch)
    }

    @objc func handleLongTouch(recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }

        // Touch is over the 5th button's x position
        let touchPoint = recognizer.location(in: self)
        guard touchPoint.x > bounds.width / 5 * 4 else {
            return
        }

        tabDelegate?.avatarLongTouch()
    }

    @objc func centerButtonAction(sender: UIButton) {
        tabDelegate?.plusButtonPressed()
    }
}

extension CGFloat {
    var degreesToRadians: CGFloat {
        return self * .pi / 180
    }

    var radiansToDegrees: CGFloat {
        return self * 180 / .pi
    }
}
