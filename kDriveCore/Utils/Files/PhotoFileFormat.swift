/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveResources
import PDFKit
import Photos
import QuickLookThumbnailing
import RealmSwift
import VisionKit

public enum PhotoFileFormat: Int, CaseIterable, PersistableEnum {
    case jpg, heic, png

    public var title: String {
        switch self {
        case .jpg:
            return "JPG"
        case .heic:
            return "HEIC"
        case .png:
            return "PNG"
        }
    }

    public var selectionTitle: String {
        switch self {
        case .jpg:
            return "JPG \(KDriveResourcesStrings.Localizable.savePhotoJpegDetail)"
        case .heic:
            return "HEIC"
        case .png:
            return "PNG"
        }
    }

    public var uti: UTI {
        switch self {
        case .jpg:
            return .jpeg
        case .heic:
            return .heic
        case .png:
            return .png
        }
    }

    public var `extension`: String {
        return uti.preferredFilenameExtension!
    }
}
