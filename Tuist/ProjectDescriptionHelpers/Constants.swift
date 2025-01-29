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

public enum Constants {
    public static let testSettings: [String: SettingValue] = [
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"
    ]

    public static let baseSettings = SettingsDictionary()
        .automaticCodeSigning(devTeam: "864VDCS2QY")
        .currentProjectVersion("1")
        .marketingVersion("5.1.0")

    public static let deploymentTarget = DeploymentTargets.iOS("13.4")
    public static let destinations = Set<Destination>([.iPhone, .iPad])

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
