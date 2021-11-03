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

protocol MainTabBarDelegate: AnyObject {
    func plusButtonPressed()
}

class MainTabBar: UITabBar {
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

    var tabBarHeight: CGFloat {
        return frame.height - safeAreaInsets.bottom
    }

    private var shapeLayer: CALayer?
    private var backgroundLayer: CALayer?

    weak var tabDelegate: MainTabBarDelegate?

    override func draw(_ rect: CGRect) {
        addShape()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        backgroundColor = KDriveAsset.backgroundCardViewColor.color
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
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = createPath()
        addShadow()
    }

    func createPath() -> CGPath {
        let buttonRadius: CGFloat = tabBarHeight / 2
        let buttonMargin: CGFloat = 8
        let path = UIBezierPath()
        let centerWidth = frame.width / 2

        path.move(to: CGPoint(x: 45, y: 0))
        path.addArc(withCenter: CGPoint(x: centerWidth - (buttonRadius + buttonMargin + 3), y: 3), radius: 3, startAngle: CGFloat(270 * Double.pi / 180), endAngle: CGFloat(0 * Double.pi / 180), clockwise: true)
        path.addArc(withCenter: CGPoint(x: centerWidth, y: 10), radius: buttonRadius + buttonMargin, startAngle: CGFloat(180 * Double.pi / 180), endAngle: CGFloat(0 * Double.pi / 180), clockwise: false)
        path.addArc(withCenter: CGPoint(x: centerWidth + (buttonRadius + buttonMargin + 3), y: 3), radius: 3, startAngle: CGFloat(180 * Double.pi / 180), endAngle: CGFloat(270 * Double.pi / 180), clockwise: true)
        path.addArc(withCenter: CGPoint(x: frame.width - 40, y: tabBarHeight / 2), radius: tabBarHeight / 2, startAngle: CGFloat(270 * Double.pi / 180), endAngle: CGFloat(90 * Double.pi / 180), clockwise: true)
        path.addArc(withCenter: CGPoint(x: 40, y: tabBarHeight / 2), radius: tabBarHeight / 2, startAngle: CGFloat(90 * Double.pi / 180), endAngle: CGFloat(270 * Double.pi / 180), clockwise: true)
        path.close()
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
        let height: CGFloat = 120
        let inset = (superview?.frame.height ?? 0) - frame.height - frame.minY
        gradient.frame = CGRect(x: 0, y: bounds.height + inset - height, width: bounds.width, height: height)
        gradient.colors = [KDriveAsset.backgroundColor.color.withAlphaComponent(0).cgColor, KDriveAsset.backgroundColor.color.cgColor]
        if let oldBackgroundLayer = backgroundLayer {
            layer.replaceSublayer(oldBackgroundLayer, with: gradient)
        } else {
            layer.insertSublayer(gradient, at: 0)
        }
        backgroundLayer = gradient
    }

    private func setupMiddleButton() {
        let originY = tabBarHeight * -18 / 60
        if centerButton?.superview != nil {
            centerButton.removeFromSuperview()
        }
        centerButton = IKRoundButton(frame: CGRect(x: (bounds.width / 2) - (tabBarHeight / 2), y: originY, width: tabBarHeight, height: tabBarHeight))
        centerButton.setTitle("", for: .normal)
        centerButton.setImage(KDriveAsset.plus.image, for: .normal)
        centerButton.accessibilityLabel = KDriveStrings.Localizable.buttonAdd
        // Shadow
        centerButton.layer.shadowPath = UIBezierPath(ovalIn: centerButton.bounds).cgPath
        centerButton.elevated = true
        centerButton.elevation = 16
        addSubview(centerButton)
        centerButton.addTarget(self, action: #selector(centerButtonAction), for: .touchUpInside)
    }

    @objc func centerButtonAction(sender: UIButton) {
        tabDelegate?.plusButtonPressed()
    }

    override open func sizeThatFits(_ size: CGSize) -> CGSize {
        var sizeThatFits = super.sizeThatFits(size)
        sizeThatFits.height = 55 + (UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0)
        return sizeThatFits
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
