/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

import AVFoundation
import kDriveResources
import UIKit

public struct MediaMetadata {
    public let title: String
    public let artist: String
    public let artwork: UIImage?

    public init(title: String, artist: String, artwork: UIImage?) {
        self.title = title
        self.artist = artist
        self.artwork = artwork
    }
}

public extension MediaMetadata {
    static func extractTrackMetadata(from url: URL, playableFileName: String?) async -> MediaMetadata {
        let asset: AVAsset

        if url.isFileURL {
            asset = AVAsset(url: url)
        } else {
            asset = AVURLAsset(url: url)
        }

        var title = playableFileName ?? KDriveResourcesStrings.Localizable.unknownTitle
        var artist = KDriveResourcesStrings.Localizable.unknownArtist
        var artwork: UIImage?

        for item in asset.commonMetadata {
            guard let commonKey = item.commonKey else { continue }

            switch commonKey {
            case .commonKeyTitle:
                title = item.value as? String ?? title
            case .commonKeyArtist:
                artist = item.value as? String ?? artist
            case .commonKeyArtwork:
                if let data = item.value as? Data {
                    artwork = UIImage(data: data)
                }
            default:
                break
            }
        }

        return MediaMetadata(title: title, artist: artist, artwork: artwork)
    }
}
