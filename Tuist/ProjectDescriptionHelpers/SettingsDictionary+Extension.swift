//
//  SettingsDictionary+Extension.swift
//  ProjectDescriptionHelpers
//
//  Created by Philippe Weidmann on 09.02.22.
//

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
