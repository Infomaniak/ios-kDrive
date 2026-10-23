/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import kDriveCore
import kDriveResources
import Testing
import UIKit

@MainActor
@Suite("Shared Interface Builder assets")
struct ResourceAssetsTests {
    @Test func imageAndButtonStateLookups() throws {
        let image = UIImageView()
        image.setValue("close", forKey: "resourceImageName")
        #expect(try #require(image.image).size == KDriveResourcesAsset.close.image.size)

        let item = UIBarButtonItem()
        item.setValue("close", forKey: "resourceImageName")
        #expect(item.image != nil)

        let button = UIButton()
        for state: UIControl.State in [.normal, .selected, .highlighted, .disabled] {
            let key: String
            switch state {
            case .selected: key = "resourceSelectedImageName"
            case .highlighted: key = "resourceHighlightedImageName"
            case .disabled: key = "resourceDisabledImageName"
            default: key = "resourceNormalImageName"
            }
            button.setValue("close", forKey: key)
            #expect(button.image(for: state) != nil)
        }
        button.setValue("infomaniakColor", forKey: "resourceNormalTitleColorName")
        button.setValue("titleColor", forKey: "resourceHighlightedTitleColorName")
        button.setValue("titleColor", forKey: "resourceDisabledTitleColorName")
        #expect(button.titleColor(for: .normal) == KDriveResourcesAsset.infomaniakColor.color)
        #expect(button.titleColor(for: .highlighted) == KDriveResourcesAsset.titleColor.color)
        #expect(button.titleColor(for: .disabled) == KDriveResourcesAsset.titleColor.color)
    }

    @Test func dynamicColorsPreserveAppearances() throws {
        let view = UIView()
        view.setValue("backgroundColor", forKey: "resourceBackgroundColorName")
        view.setValue("infomaniakColor", forKey: "resourceTintColorName")
        let color = try #require(view.backgroundColor)
        for style: UIUserInterfaceStyle in [.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            #expect(color.resolvedColor(with: traits) == KDriveResourcesAsset.backgroundColor.color.resolvedColor(with: traits))
        }
        #expect(view.tintColor == KDriveResourcesAsset.infomaniakColor.color)
    }

    @Test func specializedControlsResolveSharedColors() {
        let color = KDriveResourcesAsset.infomaniakColor.color
        let controls: [(NSObject, String)] = [
            (UILabel(), "textColor"),
            (UITextField(), "textColor"),
            (UITextView(), "textColor"),
            (UISwitch(), "onTintColor"),
            (UISegmentedControl(), "selectedSegmentTintColor"),
            (UIProgressView(), "progressTintColor"),
            (UIActivityIndicatorView(), "color"),
            (UISlider(), "maximumTrackTintColor")
        ]
        for (control, property) in controls {
            let key = "resource" + property.prefix(1).uppercased() + property.dropFirst() + "Name"
            control.setValue("infomaniakColor", forKey: key)
            #expect(control.value(forKey: property) as? UIColor == color)
        }
    }

    @Test func nibResolvesImagesAndColorsWithoutMainCatalog() throws {
        let objects = try #require(Bundle.main.loadNibNamed("SelectView", owner: nil))
        let view = try #require(objects.first as? UIView)
        func buttons(in view: UIView) -> [UIButton] {
            (view as? UIButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
        }
        #expect(buttons(in: view).contains { $0.image(for: .normal) != nil })
        #expect(view.backgroundColor == KDriveResourcesAsset.backgroundColor.color)
    }
}
