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

import Foundation
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(name: "kDrive",
                      options: .options(
                          automaticSchemesOptions: .enabled(
                              targetSchemesGrouping: .notGrouped
                          ),
                          developmentRegion: "en"
                      ),
                      targets: [
                          .target(name: "kDrive",
                                  destinations: Constants.destinations,
                                  product: .app,
                                  bundleId: "com.infomaniak.drive",
                                  deploymentTargets: Constants.deploymentTarget,
                                  infoPlist: .file(path: "kDrive/Resources/Info.plist"),
                                  sources: "kDrive/**",
                                  resources: [
                                      "kDrive/**/*.storyboard",
                                      "kDrive/**/*.xcassets",
                                      "kDrive/Resources/AppIcon.icon/**",
                                      "kDrive/**/*.strings",
                                      "kDrive/**/*.stringsdict",
                                      "kDrive/**/*.xib",
                                      "kDrive/**/*.json",
                                      "kDrive/IAP/ProductIds.plist",
                                      "kDrive/**/PrivacyInfo.xcprivacy"
                                  ],
                                  entitlements: "kDrive/Resources/kDrive.entitlements",
                                  scripts: [Constants.swiftlintScript],
                                  dependencies: [
                                      .target(name: "kDriveFileProvider"),
                                      .target(name: "kDriveCore"),
                                      .target(name: "kDriveShareExtension"),
                                      .target(name: "kDriveActionExtension"),
                                      .target(name: "kDriveResources"),
                                      .external(name: "Atlantis"),
                                      .external(name: "CocoaLumberjackSwift"),
                                      .external(name: "CocoaLumberjack"),
                                      .external(name: "DeviceAssociation"),
                                      .external(name: "DifferenceKit"),
                                      .external(name: "DropDown"),
                                      .external(name: "FloatingPanel"),
                                      .external(name: "HighlightSwift"),
                                      .external(name: "HorizonCalendar"),
                                      .external(name: "InAppTwoFactorAuthentication"),
                                      .external(name: "InfomaniakBugTracker"),
                                      .external(name: "InfomaniakCoreCommonUI"),
                                      .external(name: "InfomaniakConcurrency"),
                                      .external(name: "InfomaniakCoreDB"),
                                      .external(name: "InfomaniakCoreUIKit"),
                                      .external(name: "InfomaniakDeviceCheck"),
                                      .external(name: "InfomaniakNotifications"),
                                      .external(name: "InfomaniakOnboarding"),
                                      .external(name: "InfomaniakPrivacyManagement"),
                                      .external(name: "InterAppLogin"),
                                      .external(name: "Kingfisher"),
                                      .external(name: "KSuiteUtils"),
                                      .external(name: "KSuite"),
                                      .external(name: "Kvitto"),
                                      .external(name: "LocalizeKit"),
                                      .external(name: "Lottie"),
                                      .external(name: "MarkdownKit"),
                                      .external(name: "MaterialOutlinedTextField"),
                                      .external(name: "MyKSuite"),
                                      .external(name: "RealmSwift"),
                                      .external(name: "Realm"),
                                      .external(name: "SwiftRegex"),
                                      .sdk(name: "StoreKit", type: .framework, status: .required)
                                  ],
                                  settings: .settings(base: Constants.baseSettings),
                                  environmentVariables: [
                                      "hostname": .environmentVariable(value: "\(ProcessInfo.processInfo.hostName).",
                                                                       isEnabled: true)
                                  ]),
                          .target(name: "kDriveTests",
                                  destinations: Constants.destinations,
                                  product: .unitTests,
                                  bundleId: "com.infomaniak.drive.mainTests",
                                  deploymentTargets: Constants.deploymentTarget, infoPlist: .default,
                                  sources: [
                                      "kDriveTests/**",
                                      "kDriveTestShared/**"
                                  ],
                                  resources: [
                                      "kDriveTests/**/*.jpg",
                                      "kDriveTests/**/*.json"
                                  ],
                                  dependencies: [
                                      .target(name: "kDrive"),
                                      .target(name: "kDriveCore"),
                                      .external(name: "Alamofire"),
                                      .external(name: "DeviceAssociation"),
                                      .external(name: "InfomaniakCoreCommonUI"),
                                      .external(name: "InfomaniakCoreUIKit"),
                                      .external(name: "InfomaniakCore"),
                                      .external(name: "InfomaniakDI"),
                                      .external(name: "InfomaniakLogin"),
                                      .external(name: "RealmSwift"),
                                      .external(name: "Realm")
                                  ],
                                  settings: .settings(base: Constants.testSettings)),
                          .target(name: "kDriveAPITests",
                                  destinations: Constants.destinations,
                                  product: .unitTests,
                                  bundleId: "com.infomaniak.drive.apiTests",
                                  deploymentTargets: Constants.deploymentTarget,
                                  infoPlist: .default,
                                  sources: [
                                      "kDriveAPITests/**",
                                      "kDriveTestShared/**"
                                  ],
                                  dependencies: [
                                      .target(name: "kDrive"),
                                      .target(name: "kDriveCore"),
                                      .external(name: "DeviceAssociation"),
                                      .external(name: "InfomaniakCore"),
                                      .external(name: "InfomaniakDI"),
                                      .external(name: "InfomaniakLogin"),
                                      .external(name: "RealmSwift"),
                                      .external(name: "Realm")
                                  ],
                                  settings: .settings(base: Constants.testSettings)),
                          .target(name: "kDriveUITests",
                                  destinations: Constants.destinations,
                                  product: .uiTests,
                                  bundleId: "com.infomaniak.drive.uiTests",
                                  deploymentTargets: Constants.deploymentTarget,
                                  infoPlist: .default,
                                  sources: "kDriveUITests/**",
                                  dependencies: [
                                      .target(name: "kDrive"),
                                      .target(name: "kDriveCore")
                                  ],
                                  settings: .settings(base: Constants.testSettings)),
                          .target(name: "kDriveResources",
                                  destinations: Constants.destinations,
                                  product: .framework,
                                  bundleId: "com.infomaniak.drive.resources",
                                  deploymentTargets: Constants.deploymentTarget,
                                  infoPlist: .default,
                                  resources: [
                                      "kDrive/**/*.xcassets",
                                      "kDrive/**/*.strings",
                                      "kDrive/**/*.stringsdict"
                                  ]),
                          .target(name: "kDriveCore",
                                  destinations: Constants.destinations,
                                  product: .framework,
                                  bundleId: "com.infomaniak.drive.core",
                                  deploymentTargets: Constants.deploymentTarget,
                                  infoPlist: .file(path: "kDriveCore/Info.plist"),
                                  sources: "kDriveCore/**",
                                  resources: [
                                      "kDrive/**/*.xcassets",
                                      "kDrive/**/*.strings",
                                      "kDrive/**/*.stringsdict"
                                  ],
                                  dependencies: [
                                      .target(name: "kDriveResources"),
                                      .external(name: "Alamofire"),
                                      .external(name: "Algorithms"),
                                      .external(name: "Atlantis"),
                                      .external(name: "CocoaLumberjackSwift"),
                                      .external(name: "CocoaLumberjack"),
                                      .external(name: "DeviceAssociation"),
                                      .external(name: "DifferenceKit"),
                                      .external(name: "InAppTwoFactorAuthentication"),
                                      .external(name: "InfomaniakBugTracker"),
                                      .external(name: "InfomaniakConcurrency"),
                                      .external(name: "InfomaniakCoreCommonUI"),
                                      .external(name: "InfomaniakCoreDB"),
                                      .external(name: "InfomaniakCoreSwiftUI"),
                                      .external(name: "InfomaniakCoreUIKit"),
                                      .external(name: "InfomaniakCore"),
                                      .external(name: "InfomaniakDeviceCheck"),
                                      .external(name: "InfomaniakDI"),
                                      .external(name: "InfomaniakLogin"),
                                      .external(name: "InfomaniakNotifications"),
                                      .external(name: "InfomaniakOnboarding"),
                                      .external(name: "InterAppLogin"),
                                      .external(name: "Kingfisher"),
                                      .external(name: "KSuiteUtils"),
                                      .external(name: "KSuite"),
                                      .external(name: "LocalizeKit"),
                                      .external(name: "MaterialOutlinedTextField"),
                                      .external(name: "MQTTNIO"),
                                      .external(name: "MyKSuite"),
                                      .external(name: "RealmSwift"),
                                      .external(name: "Realm"),
                                      .external(name: "Sentry-Dynamic"),
                                      .external(name: "SwiftRegex"),
                                      .external(name: "VersionChecker")
                                  ]),
                          .target(name: "kDriveFileProvider",
                                  destinations: Constants.destinations,
                                  product: .appExtension,
                                  bundleId: "com.infomaniak.drive.FileProvider",
                                  deploymentTargets: Constants.deploymentTarget,
                                  infoPlist: .file(path: "kDriveFileProvider/Info.plist"),
                                  sources: [
                                      "kDriveFileProvider/**",
                                      "kDrive/Utils/AppFactoryService.swift",
                                      "kDrive/Utils/AppExtensionRouter.swift",
                                      "kDrive/Utils/NavigationManager.swift"
                                  ],
                                  resources: [
                                      "kDrive/**/PrivacyInfo.xcprivacy"
                                  ],
                                  headers: .headers(project: "kDriveFileProvider/**"),
                                  entitlements: "kDriveFileProvider/FileProvider.entitlements",
                                  dependencies: [
                                      .target(name: "kDriveCore"),
                                      .external(name: "CocoaLumberjackSwift"),
                                      .external(name: "CocoaLumberjack"),
                                      .external(name: "InfomaniakCore"),
                                      .external(name: "InfomaniakCoreCommonUI"),
                                      .external(name: "InfomaniakDI"),
                                      .external(name: "InfomaniakLogin"),
                                      .external(name: "RealmSwift")
                                  ],
                                  settings: .settings(
                                      base: Constants.fileProviderSettings,
                                      debug: Constants.debugFileProviderSettings
                                  )),
                          .extensionTarget(name: "kDriveShareExtension",
                                           bundleId: "com.infomaniak.drive.ShareExtension",
                                           entitlements: "kDriveShareExtension/ShareExtension.entitlements",
                                           settings: .settings(
                                               base: Constants.shareExtensionSettings,
                                               debug: Constants.debugShareExtensionSettings
                                           )),
                          .extensionTarget(name: "kDriveActionExtension",
                                           bundleId: "com.infomaniak.drive.ActionExtension",
                                           entitlements: "kDriveActionExtension/ActionExtension.entitlements",
                                           additionalResources: ["kDriveActionExtension/**/*.xcassets",
                                                                 "kDriveActionExtension/**/*.strings"],
                                           settings: .settings(
                                               base: Constants.actionExtensionSettings,
                                               debug: Constants.debugActionExtensionSettings
                                           ))
                      ],
                      fileHeaderTemplate: .file("file-header-template.txt"))
