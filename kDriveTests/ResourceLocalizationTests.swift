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
@Suite("Interface Builder resource localization")
struct ResourceLocalizationTests {
    @Test func bundledNibUsesSharedTranslation() throws {
        let objects = try #require(Bundle.main.loadNibNamed("ImportingTableViewCell", owner: nil))
        let cell = try #require(objects.first as? UITableViewCell)
        func labels(in view: UIView) -> [UILabel] {
            (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
        }
        #expect(labels(in: cell).contains { $0.text == KDriveResourcesStrings.Localizable.uploadInProgressTitle })
    }

    @Test func runtimeAttributesResolveInSharedBundle() {
        let expected = KDriveResourcesStrings.Localizable.buttonClose
        let controls: [(NSObject, String)] = [
            (UILabel(), "text"),
            (UINavigationItem(), "title"),
            (UIBarButtonItem(), "title"),
            (UITabBarItem(), "title"),
            (UITextView(), "text")
        ]
        for (control, property) in controls {
            control.setValue("buttonClose", forKey: "xibLocKey")
            #expect(control.value(forKey: property) as? String == expected)
        }

        let button = UIButton()
        button.setValue("buttonClose", forKey: "xibLocKey")
        button.setValue("buttonClose", forKey: "xibLocKeyDisabled")
        #expect(button.title(for: .normal) == expected)
        #expect(button.title(for: .disabled) == expected)

        let field = UITextField()
        field.setValue("buttonClose", forKey: "xibPlaceholderLocKey")
        #expect(field.placeholder == expected)

        let segments = UISegmentedControl(items: ["first", "second"])
        segments.setValue("buttonClose,buttonValid", forKey: "xibLocKeys")
        #expect(segments.titleForSegment(at: 0) == expected)
        #expect(segments.titleForSegment(at: 1) == KDriveResourcesStrings.Localizable.buttonValid)
    }
}
