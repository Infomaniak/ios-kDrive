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

// MARK: - Direction
enum Direction {
    case UP
    case DOWN
    case LEFT
    case RIGHT
}

extension Direction {
    static func fromPopoverArrowDirection(direction: UIPopoverArrowDirection) -> Direction? {
        switch direction {
        case UIPopoverArrowDirection.up:
            return .UP
        case UIPopoverArrowDirection.down:
            return .DOWN
        case UIPopoverArrowDirection.left:
            return .LEFT
        case UIPopoverArrowDirection.right:
            return .RIGHT
        default:
            return nil
        }
    }

    func toPopoverArrowDirection() -> UIPopoverArrowDirection {
        switch self {
        case .UP:
            return UIPopoverArrowDirection.up
        case .DOWN:
            return UIPopoverArrowDirection.down
        case .LEFT:
            return UIPopoverArrowDirection.left
        case .RIGHT:
            return UIPopoverArrowDirection.right
        }
    }
}

// MARK: - Arrow
private struct Arrow {
    let height: CGFloat = 10.0
    let base: CGFloat = 20.0

    var direction: Direction = .UP
    var offset: CGFloat = 0.0

    func frame(container: CGRect) -> CGRect {
        let containerMidX = container.midX
        let containerMidY = container.midY
        let containerWidth = container.size.width
        let containerHeight = container.size.height

        let halfBase = base / 2.0

        let x: CGFloat
        let y: CGFloat
        let size: CGSize = frameSize()

        switch direction {
        case .UP:
            x = containerMidX + offset - halfBase
            y = 0.0
        case .DOWN:
            x = containerMidX + offset - halfBase
            y = containerHeight - height
        case .LEFT:
            x = 0.0
            y = containerMidY + offset - halfBase
        case .RIGHT:
            x = containerWidth - height
            y = containerMidY + offset - halfBase
        }
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func frameSize() -> CGSize {
        switch direction {
        case .UP, .DOWN:
            return CGSize(width: base, height: height)
        case .LEFT, .RIGHT:
            return CGSize(width: height, height: base)
        }
    }
}

// MARK: - PopoverBackground
class PopoverBackground: UIPopoverBackgroundView {

    var backgroundView = UIImageView()
    private var arrow: Arrow = Arrow()
    private static let PROTO_ARROW = Arrow()

    override var arrowDirection: UIPopoverArrowDirection {
        get {
            return arrow.direction.toPopoverArrowDirection()
        }
        set {
            if let direction = Direction.fromPopoverArrowDirection(direction: newValue) {
                arrow.direction = direction
                setNeedsLayout()
            }
        }
    }

    override var arrowOffset: CGFloat {
        get {
            return arrow.offset
        }
        set {
            arrow.offset = newValue
            setNeedsLayout()
        }
    }

    override static func arrowBase() -> CGFloat {
        return PROTO_ARROW.base
    }

    override static func contentViewInsets() -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    override static func arrowHeight() -> CGFloat {
        return PROTO_ARROW.height
    }

    override func layoutSubviews() {
        let arrowFrame = arrow.frame(container: self.bounds)
        var backgroundFrame = self.bounds

        switch arrow.direction {
        case .UP:
            backgroundFrame.origin.y += arrowFrame.height
            backgroundFrame.size.height -= arrowFrame.height
        case .DOWN:
            backgroundFrame.size.height -= arrowFrame.height
        case .LEFT:
            backgroundFrame.origin.x += arrowFrame.width
            backgroundFrame.size.width -= arrowFrame.width
        case .RIGHT:
            backgroundFrame.size.width -= arrowFrame.width
        }

        backgroundView.frame = backgroundFrame
        backgroundView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8)
        backgroundView.cornerRadius = 6
        self.addSubview(backgroundView)
    }

}
