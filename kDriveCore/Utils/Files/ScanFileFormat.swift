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

public enum ScanFileFormat: Int, CaseIterable {
    case pdf, image

    public var title: String {
        switch self {
        case .pdf:
            return "PDF"
        case .image:
            return "Image (.JPG)"
        }
    }

    public var uti: UTI {
        switch self {
        case .pdf:
            return .pdf
        case .image:
            return .jpeg
        }
    }

    public var `extension`: String {
        return uti.preferredFilenameExtension!
    }
}
