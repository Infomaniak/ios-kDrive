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

import InfomaniakLogin
@testable import kDrive
@testable import kDriveCore
import Testing
import UIKit

@MainActor
@Suite
struct UTAdaptiveLayout {
    @Test func singleScreenAndLandscapeStayCompact() {
        #expect(traits(.compact, .regular).iskDriveCompactSize)
        #expect(traits(.regular, .compact).iskDriveCompactSize)
        #expect(traits(.unspecified, .unspecified).iskDriveCompactSize)
    }

    @Test func expandedPhoneAndWideIPadUseSidebar() {
        #expect(!traits(.regular, .regular).iskDriveCompactSize)
        #expect(!traits(.regular, .regular, idiom: .pad).iskDriveCompactSize)
        #expect(traits(.compact, .regular, idiom: .pad).iskDriveCompactSize)
    }

    @Test func foldingPreservesNavigationStackAndSelectedTab() throws {
        let split = makeSplitController()
        let tabs = try #require(split.viewController(for: .compact) as? MainTabViewController)
        let navigation = try #require(tabs.selectedViewController as? UINavigationController)
        let detail = try #require(split.viewController(for: .secondary) as? UINavigationController)
        let root = UIViewController()
        let preview = UIViewController()
        navigation.setViewControllers([root, preview], animated: false)

        for _ in 0 ..< 3 {
            _ = split.splitViewController(split, displayModeForExpandingToProposedDisplayMode: .automatic)
            #expect(detail.viewControllers.first === root)
            #expect(detail.topViewController === preview)
            #expect(preview.navigationController === detail)

            // A repeated expansion callback must not replace the visible stack with its placeholder.
            _ = split.splitViewController(split, displayModeForExpandingToProposedDisplayMode: .automatic)
            #expect(detail.topViewController === preview)

            _ = split.splitViewController(split, topColumnForCollapsingToProposedTopColumn: .primary)
            #expect(navigation.viewControllers.first === root)
            #expect(navigation.topViewController === preview)
            #expect(preview.navigationController === navigation)
            #expect(tabs.selectedIndex == MainTabBarIndex.gallery.rawValue)
        }
    }

    @Test func landscapeOverrideIsRemovedWhenUnfolded() throws {
        guard #available(iOS 17.0, *) else { return }
        let split = makeSplitController()
        split.updateLayoutTraits(from: traits(.regular, .compact))
        #expect(split.traitOverrides.horizontalSizeClass == .compact)

        split.updateLayoutTraits(from: traits(.regular, .regular))
        #expect(!split.traitOverrides.contains(UITraitHorizontalSizeClass.self))
    }

    private func traits(_ horizontal: UIUserInterfaceSizeClass,
                        _ vertical: UIUserInterfaceSizeClass,
                        idiom: UIUserInterfaceIdiom = .phone) -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(horizontalSizeClass: horizontal),
            UITraitCollection(verticalSizeClass: vertical),
            UITraitCollection(userInterfaceIdiom: idiom)
        ])
    }

    private func makeSplitController() -> RootSplitViewController {
        let token = ApiToken(accessToken: "", expiresIn: 0, refreshToken: "", scope: "", tokenType: "", userId: 0,
                             expirationDate: Date())
        let manager = DriveFileManager(drive: Drive(), apiFetcher: DriveApiFetcher(token: token, delegate: MCKTokenDelegate()))
        return RootSplitViewController(driveFileManager: manager, selectedIndex: MainTabBarIndex.gallery.rawValue)
    }
}
