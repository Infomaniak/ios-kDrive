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

let baseSettings: [String: SettingValue] = [
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "864VDCS2QY",
    "CURRENT_PROJECT_VERSION": "5",
    "MARKETING_VERSION": "4.0.2"
]

let fileProviderSettings = baseSettings.merging(["SWIFT_OBJC_BRIDGING_HEADER": "kDriveFileProvider/Validation/kDriveFileProvider-Bridging-Header.h", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "ISEXTENSION"]) { (first, _) in first }
let debugFileProviderSettings = baseSettings.merging(["SWIFT_OBJC_BRIDGING_HEADER": "kDriveFileProvider/Validation/kDriveFileProvider-Bridging-Header.h", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "ISEXTENSION DEBUG"]) { (first, _) in first }

let shareExtensionSettings = baseSettings.merging(["SWIFT_ACTIVE_COMPILATION_CONDITIONS": "ISEXTENSION"]) { (first, _) in first }

let debugShareExtensionSettings = baseSettings.merging(["SWIFT_ACTIVE_COMPILATION_CONDITIONS": "ISEXTENSION DEBUG"]) { (first, _) in first }

let actionExtensionSettings = baseSettings.merging(["SWIFT_ACTIVE_COMPILATION_CONDITIONS": "ISEXTENSION", "ASSETCATALOG_COMPILER_APPICON_NAME": "ExtensionIcon"]) { (first, _) in first }

let debugActionExtensionSettings = baseSettings.merging(["SWIFT_ACTIVE_COMPILATION_CONDITIONS": "ISEXTENSION DEBUG", "ASSETCATALOG_COMPILER_APPICON_NAME": "ExtensionIcon"]) { (first, _) in first }

let project = Project(name: "kDrive",
    packages: [
            .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.2.2")),
            .package(url: "https://github.com/Infomaniak/ios-core.git", .upToNextMajor(from: "1.0.1")),
            .package(url: "https://github.com/Infomaniak/ios-login.git", .upToNextMajor(from: "1.4.0")),
            .package(url: "https://github.com/realm/realm-cocoa", .upToNextMajor(from: "10.0.0")),
            .package(url: "https://github.com/SCENEE/FloatingPanel", .upToNextMajor(from: "2.0.0")),
            .package(url: "https://github.com/onevcat/Kingfisher", .upToNextMajor(from: "5.15.6")),
            .package(url: "https://github.com/flowbe/MaterialOutlinedTextField", .upToNextMajor(from: "0.1.0")),
            .package(url: "https://github.com/ProxymanApp/atlantis", .upToNextMajor(from: "1.3.0")),
            .package(url: "https://github.com/gmarm/BetterSegmentedControl.git", .upToNextMajor(from: "2.0.0")),
            .package(url: "https://github.com/ra1028/DifferenceKit", .upToNextMajor(from: "1.1.5")),
            .package(url: "https://github.com/immortal79/LocalizeKit", .upToNextMajor(from: "1.0.1")),
            .package(url: "https://github.com/airbnb/lottie-ios.git", .upToNextMajor(from: "3.1.9")),
            .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMajor(from: "3.7.0")),
            .package(url: "https://github.com/RomanTysiachnik/DropDown.git", .branch("master")),
            .package(url: "https://github.com/PhilippeWeidmann/SnackBar.swift", .upToNextMajor(from: "0.1.2")),
            .package(url: "https://github.com/flowbe/SwiftRegex.git", .upToNextMajor(from: "1.0.0")),
            .package(url: "https://github.com/getsentry/sentry-cocoa", .upToNextMajor(from: "6.2.1"))
    ],
    targets: [
        Target(name: "kDrive",
            platform: .iOS,
            product: .app,
            bundleId: "com.infomaniak.drive",
            deploymentTarget: .iOS(targetVersion: "12.0", devices: [.iphone, .ipad]),
            infoPlist: "kDrive/Resources/Info.plist",
            sources: "kDrive/**",
            resources: [
                "kDrive/**/*.storyboard",
                "kDrive/**/*.xcassets",
                "kDrive/**/*.strings",
                "kDrive/**/*.stringsdict",
                "kDrive/**/*.xib",
                "kDrive/**/*.json"
            ],
            entitlements: "kDrive/Resources/kDrive.entitlements",
            dependencies: [
                    .target(name: "kDriveFileProvider"),
                    .target(name: "kDriveCore"),
                    .target(name: "kDriveShareExtension"),
                    .target(name: "kDriveActionExtension"),
                    .package(product: "FloatingPanel"),
                    .package(product: "BetterSegmentedControl"),
                    .package(product: "Lottie"),
                    .package(product: "DropDown")
            ],
            settings: Settings(base: baseSettings)),
        Target(name: "kDriveTests",
            platform: .iOS,
            product: .unitTests,
            bundleId: "com.infomaniak.drive.tests",
            deploymentTarget: .iOS(targetVersion: "12.0", devices: [.iphone]),
            infoPlist: "kDriveTests/Tests.plist",
            sources: "kDriveTests/**",
            dependencies: [
                    .target(name: "kDrive"),
            ],
            settings: Settings(base: ["CODE_SIGN_IDENTITY": "", "CODE_SIGNING_REQUIRED": "NO"])),
        Target(name: "kDriveUITests",
            platform: .iOS,
            product: .uiTests,
            bundleId: "com.infomaniak.drive.uitests",
            deploymentTarget: .iOS(targetVersion: "12.0", devices: [.iphone]),
            infoPlist: "kDriveTests/Tests.plist",
            sources: "kDriveUITests/**",
            dependencies: [
                    .target(name: "kDrive"),
                    .target(name: "kDriveCore")
            ]),
        Target(name: "kDriveCore",
            platform: .iOS,
            product: .framework,
            bundleId: "com.infomaniak.drive.core",
            deploymentTarget: .iOS(targetVersion: "12.0", devices: [.iphone, .ipad]),
            infoPlist: "kDriveCore/Info.plist",
            sources: "kDriveCore/**",
            resources: [
                "kDrive/**/*.xcassets",
                "kDrive/**/*.strings",
                "kDrive/**/*.stringsdict",
                "kDriveCore/**/*.storyboard",
                "kDriveCore/**/*.xcassets",
                "kDriveCore/**/*.xib",
                "kDriveCore/**/*.json"
            ],
            dependencies: [
                    .package(product: "Alamofire"),
                    .package(product: "Atlantis"),
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
                    .package(product: "Sentry")
            ]),
        Target(name: "kDriveFileProvider",
            platform: .iOS,
            product: .appExtension,
            bundleId: "com.infomaniak.drive.FileProvider",
            deploymentTarget: .iOS(targetVersion: "12.0", devices: [.iphone, .ipad]),
            infoPlist: .extendingDefault(with: [
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleDisplayName": "kDrive",
                "AppIdentifierPrefix": "$(AppIdentifierPrefix)",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.fileprovider-nonui",
                    "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).FileProviderExtension",
                    "NSExtensionFileProviderDocumentGroup": "group.com.infomaniak.drive",
                    "NSExtensionFileProviderSupportsEnumeration": true
                ]
                ]),
            sources: "kDriveFileProvider/**",
            headers: Headers(project: "kDriveFileProvider/**"),
            entitlements: "kDriveFileProvider/FileProvider.entitlements",
            dependencies: [
                    .target(name: "kDriveCore")
            ],
            settings: Settings(base: fileProviderSettings, debug: Configuration(settings: debugFileProviderSettings))),
        Target(name: "kDriveShareExtension",
            platform: .iOS,
            product: .appExtension,
            bundleId: "com.infomaniak.drive.ShareExtension",
            deploymentTarget: .iOS(targetVersion: "12.0", devices: [.iphone, .ipad]),
            infoPlist: .extendingDefault(with: [
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleDisplayName": "$(PRODUCT_NAME)",
                "AppIdentifierPrefix": "$(AppIdentifierPrefix)",
                "NSExtension": [
                    "NSExtensionMainStoryboard": "MainInterface",
                    "NSExtensionPointIdentifier": "com.apple.share-services",
                    "NSExtensionAttributes": ["NSExtensionActivationRule": "SUBQUERY (extensionItems, $extensionItem, SUBQUERY ($extensionItem.attachments, $attachment, (ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO \"public.data\")).@count == $extensionItem.attachments.@count ).@count > 0"]
                ]
                ]),
            sources: ["kDriveShareExtension/**",
                "kDrive/UI/Controller/Alert/AlertFieldViewController.swift",
                "kDrive/UI/Controller/Alert/AlertTextViewController.swift",
                "kDrive/UI/Controller/Alert/AlertViewController.swift",
                "kDrive/UI/Controller/Create File/FloatingPanelUtils.swift",
                "kDrive/UI/Controller/Files/Rights and Share/**",
                "kDrive/UI/Controller/Files/Save File/**",
                "kDrive/UI/Controller/Files/Search/**",
                "kDrive/UI/Controller/Files/FileListCollectionViewController.swift",
                "kDrive/UI/Controller/Files/FloatingPanelSortOptionTableViewController.swift",
                "kDrive/UI/Controller/Floating Panel Information/**",
                "kDrive/UI/Controller/NewFolder/**",
                "kDrive/UI/View/EmptyTableView/**",
                "kDrive/UI/View/Header view/**",
                "kDrive/UI/View/Files/FileDetail/ShareLink/**",
                "kDrive/UI/View/Files/SaveFile/**",
                "kDrive/UI/View/Files/Search/**",
                "kDrive/UI/View/Files/Upload/**",
                "kDrive/UI/View/Files/FileCollectionViewCell.swift",
                "kDrive/UI/View/Files/FileGridCollectionViewCell.swift",
                "kDrive/UI/View/Files/SwipableCell.swift",
                "kDrive/UI/View/Files/SwipableCollectionView.swift",
                "kDrive/UI/View/Files/FloatingPanel/FloatingPanelSortOptionTableViewCell.swift",
                "kDrive/UI/View/Files/FloatingPanel/FloatingPanelTableViewCell.swift",
                "kDrive/UI/View/Footer view/**",
                "kDrive/UI/View/Menu/SwitchUser/**",
                "kDrive/UI/View/Menu/MenuTableViewCell.swift",
                "kDrive/UI/View/NewFolder/**",
                "kDrive/Utils/**",
                "Derived/Sources/Assets+KDrive.swift",
                "Derived/Sources/Bundle+kDrive.swift",
                "Derived/Sources/Strings+kDrive.swift"],
            resources: [
                "kDriveShareExtension/**/*.storyboard",
                "kDrive/UI/Controller/Files/**/*.storyboard",
                "kDrive/UI/Controller/Floating Panel Information/*.storyboard",
                "kDrive/UI/Controller/NewFolder/*.storyboard",
                "kDrive/UI/View/EmptyTableView/**/*.xib",
                "kDrive/UI/View/Header view/**/*.xib",
                "kDrive/UI/View/Files/FileCollectionViewCell.xib",
                "kDrive/UI/View/Files/FileGridCollectionViewCell.xib",
                "kDrive/UI/View/Files/FileDetail/ShareLink/*.xib",
                "kDrive/UI/View/Files/SaveFile/*.xib",
                "kDrive/UI/View/Files/Search/*.xib",
                "kDrive/UI/View/Files/Upload/*.xib",
                "kDrive/UI/View/Files/FloatingPanel/FloatingPanelSortOptionTableViewCell.xib",
                "kDrive/UI/View/Files/FloatingPanel/FloatingPanelTableViewCell.xib",
                "kDrive/UI/View/Footer view/*.xib",
                "kDrive/UI/View/Menu/MenuTableViewCell.xib",
                "kDrive/UI/View/Menu/SwitchUser/*.xib",
                "kDrive/UI/View/NewFolder/*.xib",
                "kDrive/**/*.xcassets",
                "kDrive/**/*.strings",
                "kDrive/**/*.stringsdict"
            ],
            entitlements: "kDriveShareExtension/ShareExtension.entitlements",
            actions: [
                /* This prevents Tuist from generating automatic resources definition for this extension
                  as disabling it seems only possible at a project level (.disableSynthesizedResourceAccessors */
                    .pre(tool: "/bin/echo", arguments: ["-n \"\" > Derived/Sources/Bundle+kDriveShareExtension.swift"], name: "Fix Tuist"),
                    .pre(tool: "/bin/echo", arguments: ["-n \"\" > Derived/Sources/Assets+KDriveShareExtension.swift"], name: "Fix Tuist"),
                    .pre(tool: "/bin/echo", arguments: ["-n \"\" > Derived/Sources/Strings+KDriveShareExtension.swift"], name: "Fix Tuist")
            ],
            dependencies: [
                    .target(name: "kDriveCore"),
                    .package(product: "FloatingPanel"),
                    .package(product: "BetterSegmentedControl"),
                    .package(product: "Lottie"),
                    .package(product: "DropDown")
            ],
            settings: Settings(base: shareExtensionSettings, debug: Configuration(settings: debugShareExtensionSettings))),
        Target(name: "kDriveActionExtension",
            platform: .iOS,
            product: .appExtension,
            bundleId: "com.infomaniak.drive.ActionExtension",
            deploymentTarget: .iOS(targetVersion: "12.0", devices: [.iphone, .ipad]),
            infoPlist: .extendingDefault(with: [
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleDisplayName": "Enregistrer dans kDrive",
                "AppIdentifierPrefix": "$(AppIdentifierPrefix)",
                "NSExtension": [
                    "NSExtensionMainStoryboard": "MainInterface",
                    "NSExtensionPointIdentifier": "com.apple.ui-services",
                    "NSExtensionAttributes": ["NSExtensionActivationRule": "SUBQUERY (extensionItems, $extensionItem, SUBQUERY ($extensionItem.attachments, $attachment, (ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO \"public.data\")).@count == $extensionItem.attachments.@count ).@count > 0",
                        "NSExtensionServiceAllowsFinderPreviewItem": true,
                        "NSExtensionServiceAllowsTouchBarItem": true,
                        "NSExtensionServiceFinderPreviewIconName": "NSActionTemplate",
                        "NSExtensionServiceTouchBarBezelColorName": "TouchBarBezel",
                        "NSExtensionServiceTouchBarIconName": "NSActionTemplate"]
                ]
                ]),
            sources: ["kDriveActionExtension/**",
                "kDrive/UI/Controller/Alert/AlertFieldViewController.swift",
                "kDrive/UI/Controller/Alert/AlertTextViewController.swift",
                "kDrive/UI/Controller/Alert/AlertViewController.swift",
                "kDrive/UI/Controller/Create File/FloatingPanelUtils.swift",
                "kDrive/UI/Controller/Files/Rights and Share/**",
                "kDrive/UI/Controller/Files/Save File/**",
                "kDrive/UI/Controller/Files/Search/**",
                "kDrive/UI/Controller/Files/FileListCollectionViewController.swift",
                "kDrive/UI/Controller/Files/FloatingPanelSortOptionTableViewController.swift",
                "kDrive/UI/Controller/Floating Panel Information/**",
                "kDrive/UI/Controller/NewFolder/**",
                "kDrive/UI/View/EmptyTableView/**",
                "kDrive/UI/View/Header view/**",
                "kDrive/UI/View/Files/FileDetail/ShareLink/**",
                "kDrive/UI/View/Files/SaveFile/**",
                "kDrive/UI/View/Files/Search/**",
                "kDrive/UI/View/Files/Upload/**",
                "kDrive/UI/View/Files/FileCollectionViewCell.swift",
                "kDrive/UI/View/Files/FileGridCollectionViewCell.swift",
                "kDrive/UI/View/Files/SwipableCell.swift",
                "kDrive/UI/View/Files/SwipableCollectionView.swift",
                "kDrive/UI/View/Files/FloatingPanel/FloatingPanelSortOptionTableViewCell.swift",
                "kDrive/UI/View/Files/FloatingPanel/FloatingPanelTableViewCell.swift",
                "kDrive/UI/View/Footer view/**",
                "kDrive/UI/View/Menu/SwitchUser/**",
                "kDrive/UI/View/Menu/MenuTableViewCell.swift",
                "kDrive/UI/View/NewFolder/**",
                "kDrive/Utils/**",
                "Derived/Sources/Assets+KDrive.swift",
                "Derived/Sources/Bundle+kDrive.swift",
                "Derived/Sources/Strings+kDrive.swift"],
            resources: [
                "kDriveActionExtension/**/*.storyboard",
                "kDrive/UI/Controller/Files/**/*.storyboard",
                "kDrive/UI/Controller/Floating Panel Information/*.storyboard",
                "kDrive/UI/Controller/NewFolder/*.storyboard",
                "kDrive/UI/View/EmptyTableView/**/*.xib",
                "kDrive/UI/View/Header view/**/*.xib",
                "kDrive/UI/View/Files/FileCollectionViewCell.xib",
                "kDrive/UI/View/Files/FileGridCollectionViewCell.xib",
                "kDrive/UI/View/Files/FileDetail/ShareLink/*.xib",
                "kDrive/UI/View/Files/SaveFile/*.xib",
                "kDrive/UI/View/Files/Search/*.xib",
                "kDrive/UI/View/Files/Upload/*.xib",
                "kDrive/UI/View/Files/FloatingPanel/FloatingPanelSortOptionTableViewCell.xib",
                "kDrive/UI/View/Files/FloatingPanel/FloatingPanelTableViewCell.xib",
                "kDrive/UI/View/Footer view/*.xib",
                "kDrive/UI/View/Menu/MenuTableViewCell.xib",
                "kDrive/UI/View/Menu/SwitchUser/*.xib",
                "kDrive/UI/View/NewFolder/*.xib",
                "kDriveActionExtension/**/*.xcassets",
                "kDrive/**/*.xcassets",
                "kDriveActionExtension/**/*.strings",
                "kDrive/**/Localizable.strings",
                "kDrive/**/*.stringsdict"
            ],
            entitlements: "kDriveActionExtension/ActionExtension.entitlements",
            actions: [
                /* This prevents Tuist from generating automatic resources definition for this extension
                  as disabling it seems only possible at a project level (.disableSynthesizedResourceAccessors */
                    .pre(tool: "/bin/echo", arguments: ["-n \"\" > Derived/Sources/Bundle+kDriveActionExtension.swift"], name: "Fix Tuist"),
                    .pre(tool: "/bin/echo", arguments: ["-n \"\" > Derived/Sources/Assets+KDriveActionExtension.swift"], name: "Fix Tuist"),
                    .pre(tool: "/bin/echo", arguments: ["-n \"\" > Derived/Sources/Strings+KDriveActionExtension.swift"], name: "Fix Tuist")
            ],
            dependencies: [
                    .target(name: "kDriveCore"),
                    .package(product: "FloatingPanel"),
                    .package(product: "BetterSegmentedControl"),
                    .package(product: "Lottie"),
                    .package(product: "DropDown")
            ],
            settings: Settings(base: actionExtensionSettings, debug: Configuration(settings: debugActionExtensionSettings))),
    ],
    fileHeaderTemplate: .file("file-header-template.txt"))
