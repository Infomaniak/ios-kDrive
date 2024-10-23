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

public final class ImportedFile: CustomStringConvertible, Equatable {
    public var name: String
    public var path: URL
    public var uti: UTI

    public init(name: String, path: URL, uti: UTI) {
        self.name = name
        self.path = path
        self.uti = uti
    }

    @discardableResult
    public func getThumbnail(completion: @escaping (UIImage) -> Void) -> QLThumbnailGenerator.Request {
        let thumbnailSize = CGSize(width: 38, height: 38)

        return FilePreviewHelper.instance.getThumbnail(url: path, thumbnailSize: thumbnailSize) { image in
            completion(image)
        }
    }

    // MARK: CustomStringConvertible

    public var description: String {
        """
        <ImportedFile :
        name:\(name)
        path:\(path)
        uti:\(uti)
        >
        """
    }

    // MARK: Equatable

    public static func == (lhs: ImportedFile, rhs: ImportedFile) -> Bool {
        return lhs.name == rhs.name && lhs.path == rhs.path && lhs.uti == rhs.uti
    }
}
