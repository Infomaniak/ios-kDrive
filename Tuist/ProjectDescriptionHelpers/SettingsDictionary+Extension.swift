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
