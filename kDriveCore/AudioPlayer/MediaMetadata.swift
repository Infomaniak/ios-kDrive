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
    static func extractTrackMetadata(from metadata: [AVMetadataItem], playableFileName: String?) async -> MediaMetadata {
        let title: String
        let artist: String
        var artwork: UIImage?

        if let titleItem = metadata.first(where: { $0.commonKey == .commonKeyTitle }),
           let titleString = try? await titleItem.load(.value) as? String {
            title = titleString
        } else {
            title = playableFileName ?? KDriveResourcesStrings.Localizable.unknownTitle
        }

        if let artistItem = metadata.first(where: { $0.commonKey == .commonKeyArtist }),
           let artistString = try? await artistItem.load(.value) as? String {
            artist = artistString
        } else {
            artist = KDriveResourcesStrings.Localizable.unknownArtist
        }

        if let artworkItem = metadata.first(where: { $0.commonKey == .commonKeyArtwork }),
           let artworkData = try? await artworkItem.load(.value) as? Data {
            artwork = UIImage(data: artworkData)
        }

        return MediaMetadata(title: title, artist: artist, artwork: artwork)
    }
}
