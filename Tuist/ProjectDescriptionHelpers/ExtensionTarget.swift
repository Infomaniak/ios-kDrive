/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2022 Infomaniak Network SA

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

import ProjectDescription

public extension Target {
    static func extensionTarget(
        name: String,
        bundleId: String,
        entitlements: String,
        additionalResources: [ResourceFileElement] = [],
        settings: Settings
    ) -> Target {
        var resources: [ResourceFileElement] = [
            "\(name)/**/*.storyboard",
            "kDrive/UI/Controller/Files/**/*.storyboard",
            "kDrive/UI/Controller/Files/**/*.xib",
            "kDrive/UI/Controller/Home/*.xib",
            "kDrive/UI/Controller/Floating Panel Information/*.storyboard",
            "kDrive/UI/Controller/NewFolder/*.storyboard",
            "kDrive/UI/View/EmptyTableView/**/*.xib",
            "kDrive/UI/View/Header view/**/*.xib",
            "kDrive/UI/View/Generic/**/*.xib",
            "kDrive/UI/View/Files/FileCollectionViewCell.xib",
            "kDrive/UI/View/Files/FileGridCollectionViewCell.xib",
            "kDrive/UI/View/Files/Categories/**/*.xib",
            "kDrive/UI/View/Files/FileDetail/ShareLink/*.xib",
            "kDrive/UI/View/Files/SaveFile/*.xib",
            "kDrive/UI/View/Files/Search/*.xib",
            "kDrive/UI/View/Files/Upload/*.xib",
            "kDrive/UI/View/Files/FloatingPanel/FloatingPanelSortOptionTableViewCell.xib",
            "kDrive/UI/View/Files/FloatingPanel/FloatingPanelQuickActionCollectionViewCell.xib",
            "kDrive/UI/View/Files/FloatingPanel/FloatingPanelTableViewCell.xib",
            "kDrive/UI/View/Footer view/*.xib",
            "kDrive/UI/View/Menu/MenuTableViewCell.xib",
            "kDrive/UI/View/Menu/PhotoList/ReusableHeaderView.xib",
            "kDrive/UI/View/Menu/SwitchUser/*.xib",
            "kDrive/UI/View/NewFolder/*.xib",
            "kDrive/**/*.xcassets",
            "kDrive/**/Localizable.strings",
            "kDrive/**/*.stringsdict",
            "kDrive/**/*.json",
            "kDrive/**/PrivacyInfo.xcprivacy"
        ]
        resources.append(contentsOf: additionalResources)

        return .target(name: name,
                       destinations: Constants.destinations,
                       product: .appExtension,
                       bundleId: bundleId,
                       deploymentTargets: Constants.deploymentTarget,
                       infoPlist: .file(path: "\(name)/Info.plist"),
                       sources: [
                           "\(name)/**",
                           "kDrive/UI/Controller/DriveUpdateRequiredViewController.swift",
                           "kDrive/UI/Controller/FloatingPanelSelectOptionViewController.swift",
                           "kDrive/UI/Controller/Create File/FloatingPanelUtils.swift",
                           "kDrive/UI/Controller/Create File/FloatingPanelLayouts.swift",
                           "kDrive/UI/Controller/Files/Categories/**",
                           "kDrive/UI/Controller/Files/Rights and Share/**",
                           "kDrive/UI/Controller/Files/Save File/**",
                           "kDrive/UI/Controller/Files/Search/**",
                           "kDrive/UI/Controller/Files/MultipleSelectionViewController.swift",
                           "kDrive/UI/Controller/Files/File List/**",
                           "kDrive/UI/Controller/Files/SidebarViewController.swift",
                           "kDrive/UI/Controller/Files/FloatingPanelSortOptionTableViewController.swift",
                           "kDrive/UI/Controller/Floating Panel Information/**",
                           "kDrive/UI/Controller/Favorite/FavoritesViewModel.swift",
                           "kDrive/UI/Controller/Menu/Share/SharedWithMeViewModel.swift",
                           "kDrive/UI/Controller/Menu/MySharesViewModel.swift",
                           "kDrive/UI/Controller/Menu/LastModificationsViewModel.swift",
                           "kDrive/UI/Controller/Menu/OfflineFilesViewModel.swift",
                           "kDrive/UI/Controller/Menu/Trash/**",
                           "kDrive/UI/Controller/NewFolder/**",
                           "kDrive/UI/Controller/Home/RootMenuHeaderView.swift",
                           "kDrive/UI/Controller/Home/HomeLargeTitleHeaderView.swift",
                           "kDrive/UI/Controller/Home/SelectSwitchDriveDelegate.swift",
                           "kDrive/UI/Controller/Storyboard.swift",
                           "kDrive/UI/View/EmptyTableView/**",
                           "kDrive/UI/View/Header view/**",
                           "kDrive/UI/View/Generic/**",
                           "kDrive/UI/View/Files/Categories/**",
                           "kDrive/UI/View/Files/FileDetail/ShareLink/**",
                           "kDrive/UI/View/Files/SaveFile/**",
                           "kDrive/UI/View/Files/Search/**",
                           "kDrive/UI/View/Files/Upload/**",
                           "kDrive/UI/View/Files/FileCollectionViewCell.swift",
                           "kDrive/UI/View/Files/FileGridCollectionViewCell.swift",
                           "kDrive/UI/View/Files/SwipableCell.swift",
                           "kDrive/UI/View/Files/SwipableCollectionView.swift",
                           "kDrive/UI/View/Files/FileListBarButton.swift",
                           "kDrive/UI/View/Files/FloatingPanel/FloatingPanelSortOptionTableViewCell.swift",
                           "kDrive/UI/View/Files/FloatingPanel/FloatingPanelQuickActionCollectionViewCell.swift",
                           "kDrive/UI/View/Files/FloatingPanel/FloatingPanelTableViewCell.swift",
                           "kDrive/UI/View/Footer view/**",
                           "kDrive/UI/View/Menu/SwitchUser/**",
                           "kDrive/UI/View/Menu/MenuTableViewCell.swift",
                           "kDrive/UI/View/Menu/PhotoList/ReusableHeaderView.swift",
                           "kDrive/UI/View/Menu/RootMenuCell.swift",
                           "kDrive/UI/View/NewFolder/**",
                           "kDrive/Utils/**"
                       ],
                       resources: .resources(resources),
                       entitlements: Entitlements(stringLiteral: entitlements),
                       dependencies: [
                           .target(name: "kDriveCore"),
                           .external(name: "FloatingPanel"),
                           .external(name: "Lottie"),
                           .external(name: "DropDown"),
                           .external(name: "HorizonCalendar"),
                           .external(name: "Realm"),
                           .external(name: "RealmSwift"),
                           .external(name: "CocoaLumberjack"),
                           .external(name: "CocoaLumberjackSwift")
                       ],
                       settings: settings)
    }
}
