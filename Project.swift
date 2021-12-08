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

import ProjectDescription

public extension SettingsDictionary {
    func marketingVersion(_ value: String) -> SettingsDictionary {
        merging(["MARKETING_VERSION": SettingValue(stringLiteral: value)])
    }

    func bridgingHeader(path value: Path) -> SettingsDictionary {
        merging(["SWIFT_OBJC_BRIDGING_HEADER": SettingValue(stringLiteral: value.pathString)])
    }

    func compilationConditions(_ value: String) -> SettingsDictionary {
        merging(["SWIFT_ACTIVE_COMPILATION_CONDITIONS": SettingValue(stringLiteral: value)])
    }

    func appIcon(name value: String) -> SettingsDictionary {
        merging(["ASSETCATALOG_COMPILER_APPICON_NAME": SettingValue(stringLiteral: value)])
    }
}

let baseSettings = SettingsDictionary()
    .automaticCodeSigning(devTeam: "864VDCS2QY")
    .currentProjectVersion("2")
    .marketingVersion("4.1.1")

let deploymentTarget = DeploymentTarget.iOS(targetVersion: "13.0", devices: [.iphone, .ipad])

let fileProviderSettings = baseSettings
    .bridgingHeader(path: "$(SRCROOT)/kDriveFileProvider/Validation/kDriveFileProvider-Bridging-Header.h")
    .compilationConditions("ISEXTENSION")
let debugFileProviderSettings = fileProviderSettings
    .compilationConditions("ISEXTENSION DEBUG")

let shareExtensionSettings = baseSettings
    .compilationConditions("ISEXTENSION")
let debugShareExtensionSettings = shareExtensionSettings
    .compilationConditions("ISEXTENSION DEBUG")

let actionExtensionSettings = baseSettings
    .compilationConditions("ISEXTENSION")
    .appIcon(name: "ExtensionIcon")
let debugActionExtensionSettings = actionExtensionSettings
    .compilationConditions("ISEXTENSION DEBUG")

let project = Project(name: "kDrive",
                      packages: [
                          .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.2.2")),
                          .package(url: "https://github.com/Infomaniak/ios-core.git", .upToNextMajor(from: "1.1.2")),
                          .package(url: "https://github.com/Infomaniak/ios-login.git", .upToNextMajor(from: "1.4.0")),
                          .package(url: "https://github.com/realm/realm-cocoa", .upToNextMajor(from: "10.0.0")),
                          .package(url: "https://github.com/SCENEE/FloatingPanel", .upToNextMajor(from: "2.0.0")),
                          .package(url: "https://github.com/onevcat/Kingfisher", .upToNextMajor(from: "7.0.0-beta.4")),
                          .package(url: "https://github.com/flowbe/MaterialOutlinedTextField", .upToNextMajor(from: "0.1.0")),
                          .package(url: "https://github.com/ProxymanApp/atlantis", .upToNextMajor(from: "1.3.0")),
                          .package(url: "https://github.com/ra1028/DifferenceKit", .upToNextMajor(from: "1.1.5")),
                          .package(url: "https://github.com/immortal79/LocalizeKit", .upToNextMajor(from: "1.0.1")),
                          .package(url: "https://github.com/airbnb/lottie-ios.git", .upToNextMajor(from: "3.1.9")),
                          .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMajor(from: "3.7.0")),
                          .package(url: "https://github.com/RomanTysiachnik/DropDown.git", .branch("master")),
                          .package(url: "https://github.com/PhilippeWeidmann/SnackBar.swift", .upToNextMajor(from: "0.1.2")),
                          .package(url: "https://github.com/flowbe/SwiftRegex.git", .upToNextMajor(from: "1.0.0")),
                          .package(url: "https://github.com/getsentry/sentry-cocoa", .upToNextMajor(from: "7.2.9")),
                          .package(url: "https://github.com/adam-fowler/mqtt-nio", .upToNextMajor(from: "2.4.0")),
                          .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "8.0.0")),
                          .package(url: "https://github.com/airbnb/HorizonCalendar.git", .upToNextMajor(from: "1.0.0")),
                          .package(url: "https://github.com/Cocoanetics/Kvitto", .upToNextMajor(from: "1.0.0"))
                      ],
                      targets: [
                          Target(name: "kDrive",
                                 platform: .iOS,
                                 product: .app,
                                 bundleId: "com.infomaniak.drive",
                                 deploymentTarget: deploymentTarget,
                                 infoPlist: .file(path: "kDrive/Resources/Info.plist"),
                                 sources: "kDrive/**",
                                 resources: [
                                     "kDrive/**/*.storyboard",
                                     "kDrive/**/*.xcassets",
                                     "kDrive/**/*.strings",
                                     "kDrive/**/*.stringsdict",
                                     "kDrive/**/*.xib",
                                     "kDrive/**/*.json",
                                     "kDrive/IAP/ProductIds.plist",
                                     "kDriveCore/GoogleService-Info.plist"
                                 ],
                                 entitlements: "kDrive/Resources/kDrive.entitlements",
                                 scripts: [
                                     .post(path: "scripts/lint.sh", name: "Swiftlint")
                                 ],
                                 dependencies: [
                                     .target(name: "kDriveFileProvider"),
                                     .target(name: "kDriveCore"),
                                     .target(name: "kDriveShareExtension"),
                                     .target(name: "kDriveActionExtension"),
                                     .package(product: "FloatingPanel"),
                                     .package(product: "Lottie"),
                                     .package(product: "DropDown"),
                                     .package(product: "HorizonCalendar"),
                                     .package(product: "Kvitto"),
                                     .sdk(name: "StoreKit.framework", status: .required)
                                 ],
                                 settings: .settings(base: baseSettings)),
                          Target(name: "kDriveTests",
                                 platform: .iOS,
                                 product: .unitTests,
                                 bundleId: "com.infomaniak.drive.tests",
                                 deploymentTarget: .iOS(targetVersion: "13.0", devices: [.iphone]),
                                 infoPlist: .file(path: "kDriveTests/Tests.plist"),
                                 sources: "kDriveTests/**",
                                 dependencies: [
                                     .target(name: "kDrive")
                                 ],
                                 settings: .settings(base: baseSettings)),
                          Target(name: "kDriveUITests",
                                 platform: .iOS,
                                 product: .uiTests,
                                 bundleId: "com.infomaniak.drive.uitests",
                                 deploymentTarget: .iOS(targetVersion: "13.0", devices: [.iphone]),
                                 infoPlist: .file(path: "kDriveTests/Tests.plist"),
                                 sources: "kDriveUITests/**",
                                 dependencies: [
                                     .target(name: "kDrive"),
                                     .target(name: "kDriveCore")
                                 ]),
                          Target(name: "kDriveResources",
                                 platform: .iOS,
                                 product: .staticLibrary,
                                 bundleId: "com.infomaniak.drive.resources",
                                 deploymentTarget: deploymentTarget,
                                 infoPlist: .default,
                                 resources: [
                                     "kDrive/**/*.xcassets",
                                     "kDrive/**/*.strings",
                                     "kDrive/**/*.stringsdict"
                                 ]),
                          Target(name: "kDriveCore",
                                 platform: .iOS,
                                 product: .framework,
                                 bundleId: "com.infomaniak.drive.core",
                                 deploymentTarget: deploymentTarget,
                                 infoPlist: .file(path: "kDriveCore/Info.plist"),
                                 sources: "kDriveCore/**",
                                 resources: [
                                     "kDrive/**/*.xcassets",
                                     "kDrive/**/*.strings",
                                     "kDrive/**/*.stringsdict"
                                 ],
                                 dependencies: [
                                     .target(name: "kDriveResources"),
                                     .package(product: "Alamofire"),
                                     .package(product: "Atlantis"),
                                     .package(product: "MQTTNIO"),
                                     .package(product: "InfomaniakCore"),
                                     .package(product: "InfomaniakLogin"),
                                     .package(product: "RealmSwift"),
                                     .package(product: "LocalizeKit"),
                                     .package(product: "Kingfisher"),
                                     .package(product: "DifferenceKit"),
                                     .package(product: "CocoaLumberjackSwift"),
                                     .package(product: "MaterialOutlinedTextField"),
                                     .package(product: "SnackBar"),
                                     .package(product: "SwiftRegex"),
                                     .package(product: "Sentry"),
                                     .package(product: "FirebaseMessaging")
                                 ]),
                          Target(name: "kDriveFileProvider",
                                 platform: .iOS,
                                 product: .appExtension,
                                 bundleId: "com.infomaniak.drive.FileProvider",
                                 deploymentTarget: deploymentTarget,
                                 infoPlist: .file(path: "kDriveFileProvider/Info.plist"),
                                 sources: "kDriveFileProvider/**",
                                 headers: Headers(project: "kDriveFileProvider/**"),
                                 entitlements: "kDriveFileProvider/FileProvider.entitlements",
                                 dependencies: [
                                     .target(name: "kDriveCore")
                                 ],
                                 settings: .settings(base: fileProviderSettings, debug: debugFileProviderSettings)),
                          Target(name: "kDriveShareExtension",
                                 platform: .iOS,
                                 product: .appExtension,
                                 bundleId: "com.infomaniak.drive.ShareExtension",
                                 deploymentTarget: deploymentTarget,
                                 infoPlist: .file(path: "kDriveShareExtension/Info.plist"),
                                 sources: [
                                     "kDriveShareExtension/**",
                                     "kDrive/UI/Controller/FloatingPanelSelectOptionViewController.swift",
                                     "kDrive/UI/Controller/Create File/FloatingPanelUtils.swift",
                                     "kDrive/UI/Controller/Files/Categories/**",
                                     "kDrive/UI/Controller/Files/Rights and Share/**",
                                     "kDrive/UI/Controller/Files/Save File/**",
                                     "kDrive/UI/Controller/Files/Search/**",
                                     "kDrive/UI/Controller/Files/MultipleSelectionViewController.swift",
                                     "kDrive/UI/Controller/Files/FileListViewController.swift",
                                     "kDrive/UI/Controller/Files/FloatingPanelSortOptionTableViewController.swift",
                                     "kDrive/UI/Controller/Floating Panel Information/**",
                                     "kDrive/UI/Controller/NewFolder/**",
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
                                     "kDrive/UI/View/Files/FloatingPanel/FloatingPanelSortOptionTableViewCell.swift",
                                     "kDrive/UI/View/Files/FloatingPanel/FloatingPanelQuickActionCollectionViewCell.swift",
                                     "kDrive/UI/View/Files/FloatingPanel/FloatingPanelTableViewCell.swift",
                                     "kDrive/UI/View/Footer view/**",
                                     "kDrive/UI/View/Menu/SwitchUser/**",
                                     "kDrive/UI/View/Menu/MenuTableViewCell.swift",
                                     "kDrive/UI/View/NewFolder/**",
                                     "kDrive/Utils/**"
                                 ],
                                 resources: [
                                     "kDriveShareExtension/**/*.storyboard",
                                     "kDrive/UI/Controller/Files/**/*.storyboard",
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
                                     "kDrive/UI/View/Menu/SwitchUser/*.xib",
                                     "kDrive/UI/View/NewFolder/*.xib",
                                     "kDrive/**/*.xcassets",
                                     "kDrive/**/*.strings",
                                     "kDrive/**/*.stringsdict",
                                     "kDrive/**/*.json"
                                 ],
                                 entitlements: "kDriveShareExtension/ShareExtension.entitlements",
                                 scripts: [
                                     .post(path: "scripts/lint.sh", name: "Swiftlint")
                                 ],
                                 dependencies: [
                                     .target(name: "kDriveCore"),
                                     .package(product: "FloatingPanel"),
                                     .package(product: "Lottie"),
                                     .package(product: "DropDown"),
                                     .package(product: "HorizonCalendar")
                                 ],
                                 settings: .settings(base: shareExtensionSettings, debug: debugShareExtensionSettings)),
                          Target(name: "kDriveActionExtension",
                                 platform: .iOS,
                                 product: .appExtension,
                                 bundleId: "com.infomaniak.drive.ActionExtension",
                                 deploymentTarget: deploymentTarget,
                                 infoPlist: .file(path: "kDriveActionExtension/Info.plist"),
                                 sources: [
                                     "kDriveActionExtension/**",
                                     "kDrive/UI/Controller/FloatingPanelSelectOptionViewController.swift",
                                     "kDrive/UI/Controller/Create File/FloatingPanelUtils.swift",
                                     "kDrive/UI/Controller/Files/Categories/**",
                                     "kDrive/UI/Controller/Files/Rights and Share/**",
                                     "kDrive/UI/Controller/Files/Save File/**",
                                     "kDrive/UI/Controller/Files/Search/**",
                                     "kDrive/UI/Controller/Files/MultipleSelectionViewController.swift",
                                     "kDrive/UI/Controller/Files/FileListViewController.swift",
                                     "kDrive/UI/Controller/Files/FloatingPanelSortOptionTableViewController.swift",
                                     "kDrive/UI/Controller/Floating Panel Information/**",
                                     "kDrive/UI/Controller/NewFolder/**",
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
                                     "kDrive/UI/View/Files/FloatingPanel/FloatingPanelSortOptionTableViewCell.swift",
                                     "kDrive/UI/View/Files/FloatingPanel/FloatingPanelQuickActionCollectionViewCell.swift",
                                     "kDrive/UI/View/Files/FloatingPanel/FloatingPanelTableViewCell.swift",
                                     "kDrive/UI/View/Footer view/**",
                                     "kDrive/UI/View/Menu/SwitchUser/**",
                                     "kDrive/UI/View/Menu/MenuTableViewCell.swift",
                                     "kDrive/UI/View/NewFolder/**",
                                     "kDrive/Utils/**"
                                 ],
                                 resources: [
                                     "kDriveActionExtension/**/*.storyboard",
                                     "kDrive/UI/Controller/Files/**/*.storyboard",
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
                                     "kDrive/UI/View/Menu/SwitchUser/*.xib",
                                     "kDrive/UI/View/NewFolder/*.xib",
                                     "kDriveActionExtension/**/*.xcassets",
                                     "kDrive/**/*.xcassets",
                                     "kDriveActionExtension/**/*.strings",
                                     "kDrive/**/Localizable.strings",
                                     "kDrive/**/*.stringsdict",
                                     "kDrive/**/*.json"
                                 ],
                                 entitlements: "kDriveActionExtension/ActionExtension.entitlements",
                                 scripts: [
                                     .post(path: "scripts/lint.sh", name: "Swiftlint")
                                 ],
                                 dependencies: [
                                     .target(name: "kDriveCore"),
                                     .package(product: "FloatingPanel"),
                                     .package(product: "Lottie"),
                                     .package(product: "DropDown"),
                                     .package(product: "HorizonCalendar")
                                 ],
                                 settings: .settings(base: actionExtensionSettings, debug: debugActionExtensionSettings))
                      ],
                      fileHeaderTemplate: .file("file-header-template.txt"))
