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

import HorizonCalendar
import UIKit

class DayRangeIndicatorView: UIView {
    init(indicatorColor: UIColor) {
        self.indicatorColor = indicatorColor

        super.init(frame: .zero)

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var framesOfDaysToHighlight = [CGRect]() {
        didSet {
            guard framesOfDaysToHighlight != oldValue else { return }
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(indicatorColor.cgColor)

        if traitCollection.layoutDirection == .rightToLeft {
            transform = .init(scaleX: -1, y: 1)
        } else {
            transform = .identity
        }

        // Get frames of day rows in the range
        var dayRowFrames = [CGRect]()
        var currentDayRowMinY: CGFloat?
        for dayFrame in framesOfDaysToHighlight {
            if dayFrame.minY != currentDayRowMinY {
                currentDayRowMinY = dayFrame.minY
                dayRowFrames.append(dayFrame)
            } else {
                let lastIndex = dayRowFrames.count - 1
                dayRowFrames[lastIndex] = dayRowFrames[lastIndex].union(dayFrame)
            }
        }

        // Draw rectangles for each day row
        for (i, dayRowFrame) in dayRowFrames.enumerated() {
            let cornerRadius = dayRowFrame.height / 2
            var roundingCorners: UIRectCorner = []
            if i == 0 {
                roundingCorners = roundingCorners.union([.topLeft, .bottomLeft])
            }
            if i == dayRowFrames.count - 1 {
                roundingCorners = roundingCorners.union([.topRight, .bottomRight])
            }
            let bezierPath = UIBezierPath(roundedRect: dayRowFrame, byRoundingCorners: roundingCorners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
            context?.addPath(bezierPath.cgPath)
            context?.fillPath()
        }
    }

    private let indicatorColor: UIColor
}

extension DayRangeIndicatorView: CalendarItemViewRepresentable {
    struct InvariantViewProperties: Hashable {
        var indicatorColor = KDriveAsset.infomaniakColor.color.withAlphaComponent(0.1)
    }

    struct ViewModel: Equatable {
        let framesOfDaysToHighlight: [CGRect]
    }

    static func makeView(withInvariantViewProperties invariantViewProperties: InvariantViewProperties) -> DayRangeIndicatorView {
        DayRangeIndicatorView(indicatorColor: invariantViewProperties.indicatorColor)
    }

    static func setViewModel(_ viewModel: ViewModel, on view: DayRangeIndicatorView) {
        view.framesOfDaysToHighlight = viewModel.framesOfDaysToHighlight
    }
}
