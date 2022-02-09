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
import ProjectDescriptionHelpers

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
                          .package(url: "https://github.com/Cocoanetics/Kvitto", .upToNextMajor(from: "1.0.0")),
                          .package(url: "https://github.com/raspu/Highlightr", .upToNextMajor(from: "2.1.0")),
                          .package(url: "https://github.com/bmoliveira/MarkdownKit.git", .upToNextMajor(from: "1.7.0")),
                          .package(url: "https://github.com/matomo-org/matomo-sdk-ios.git", .upToNextMajor(from: "7.5.1"))
                      ],
                      targets: [
                          Target(name: "kDrive",
                                 platform: .iOS,
                                 product: .app,
                                 bundleId: "com.infomaniak.drive",
                                 deploymentTarget: Constants.deploymentTarget,
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
                                 scripts: [Constants.swiftlintScript],
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
                                     .package(product: "Highlightr"),
                                     .package(product: "MarkdownKit"),
                                     .package(product: "MatomoTracker"),
                                     .sdk(name: "StoreKit.framework", status: .required)
                                 ],
                                 settings: .settings(base: Constants.baseSettings)),
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
                                 settings: .settings(base: Constants.baseSettings)),
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
                                 deploymentTarget: Constants.deploymentTarget,
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
                                 deploymentTarget: Constants.deploymentTarget,
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
                                 deploymentTarget: Constants.deploymentTarget,
                                 infoPlist: .file(path: "kDriveFileProvider/Info.plist"),
                                 sources: "kDriveFileProvider/**",
                                 headers: Headers(project: "kDriveFileProvider/**"),
                                 entitlements: "kDriveFileProvider/FileProvider.entitlements",
                                 dependencies: [
                                     .target(name: "kDriveCore")
                                 ],
                                 settings: .settings(base: Constants.fileProviderSettings, debug: Constants.debugFileProviderSettings)),
                          .extensionTarget(name: "kDriveShareExtension",
                                           bundleId: "com.infomaniak.drive.ShareExtension",
                                           entitlements: "kDriveShareExtension/ShareExtension.entitlements",
                                           settings: .settings(base: Constants.shareExtensionSettings, debug: Constants.debugShareExtensionSettings)),
                          .extensionTarget(name: "kDriveActionExtension",
                                           bundleId: "com.infomaniak.drive.ActionExtension",
                                           entitlements: "kDriveActionExtension/ActionExtension.entitlements",
                                           additionalResources: ["kDriveActionExtension/**/*.xcassets",
                                                                 "kDriveActionExtension/**/*.strings"],
                                           settings: .settings(base: Constants.actionExtensionSettings, debug: Constants.debugActionExtensionSettings))
                      ],
                      fileHeaderTemplate: .file("file-header-template.txt"))
