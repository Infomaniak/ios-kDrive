//
//  Constants.swift
//  ProjectDescriptionHelpers
//
//  Created by Philippe Weidmann on 09.02.22.
//

import ProjectDescription

public enum Constants {
    public static let baseSettings = SettingsDictionary()
        .automaticCodeSigning(devTeam: "864VDCS2QY")
        .currentProjectVersion("1")
        .marketingVersion("4.1.3")

    public static let deploymentTarget = DeploymentTarget.iOS(targetVersion: "13.0", devices: [.iphone, .ipad])

    public static let fileProviderSettings = baseSettings
        .bridgingHeader(path: "$(SRCROOT)/kDriveFileProvider/Validation/kDriveFileProvider-Bridging-Header.h")
        .compilationConditions("ISEXTENSION")
    public static let debugFileProviderSettings = fileProviderSettings
        .compilationConditions("ISEXTENSION DEBUG")

    public static let shareExtensionSettings = baseSettings
        .compilationConditions("ISEXTENSION")
    public static let debugShareExtensionSettings = shareExtensionSettings
        .compilationConditions("ISEXTENSION DEBUG")

    public static let actionExtensionSettings = baseSettings
        .compilationConditions("ISEXTENSION")
        .appIcon(name: "ExtensionIcon")
    public static let debugActionExtensionSettings = actionExtensionSettings
        .compilationConditions("ISEXTENSION DEBUG")

    public static let swiftlintScript = TargetScript.post(path: "scripts/lint.sh", name: "Swiftlint")
}
