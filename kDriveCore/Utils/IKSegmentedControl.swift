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

@IBDesignable public class IKSegmentedControl: UISegmentedControl {
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUpControl()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpControl()
    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUpControl()
    }

    private func setUpControl() {
        var size: CGFloat = 14
        if UIScreen.main.bounds.width < 390 {
            size = ceil(size * UIScreen.main.bounds.width / 390)
        }
        let font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: size))
        setTitleTextAttributes([.foregroundColor: KDriveCoreAsset.disconnectColor.color, .font: font], for: .normal)
        setTitleTextAttributes([.foregroundColor: UIColor.white, .font: font], for: .selected)
        backgroundColor = KDriveCoreAsset.backgroundColor.color
        if #available(iOS 13.0, *) {
            selectedSegmentTintColor = KDriveCoreAsset.infomaniakColor.color
        }
    }

    public func setSegments(_ segments: [String], selectedSegmentIndex: Int = 0) {
        removeAllSegments()
        for i in 0 ..< segments.count {
            insertSegment(withTitle: segments[i], at: i, animated: false)
        }
        self.selectedSegmentIndex = selectedSegmentIndex
    }
}
