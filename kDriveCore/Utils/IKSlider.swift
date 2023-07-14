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

import kDriveResources
import UIKit

@IBDesignable class IKSlider: UISlider {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpSlider()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpSlider()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUpSlider()
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let customBounds = CGRect(origin: bounds.origin, size: CGSize(width: bounds.width, height: 10))
        super.trackRect(forBounds: customBounds)
        return customBounds
    }

    private func setUpSlider() {
        maximumTrackTintColor = KDriveResourcesAsset.borderColor.color
        // Change thumb
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28))
        let circleImage = renderer.image { ctx in
            KDriveResourcesAsset.infomaniakColor.color.setFill()
            KDriveResourcesAsset.backgroundCardViewColor.color.setStroke()
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 4,
                color: UIColor(red: 0, green: 0, blue: 0, alpha: 0.12).cgColor
            )
            let rect = CGRect(x: 3, y: 3, width: 20, height: 20)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fillStroke)
        }
        setThumbImage(circleImage, for: .normal)
    }
}
