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

import UIKit
import AVFoundation

extension UIImage {
    private var orientationMapping: [Orientation: CGImagePropertyOrientation] {
        return [.up: .up, .upMirrored: .upMirrored, .down: .down, .downMirrored: .downMirrored, .left: .left, .leftMirrored: .leftMirrored, .right: .right, .rightMirrored: .rightMirrored]
    }

    public func heicData(compressionQuality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(data, AVFileType.heic as CFString, 1, nil),
            let cgImage = self.cgImage else {
            return nil
        }
        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
            kCGImagePropertyOrientation: orientationMapping[imageOrientation]!.rawValue
        ]
        CGImageDestinationAddImage(imageDestination, cgImage, options)
        if CGImageDestinationFinalize(imageDestination) {
            return data as Data
        } else {
            return nil
        }
    }
}
