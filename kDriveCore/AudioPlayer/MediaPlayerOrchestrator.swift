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

import Foundation

public protocol Pausable {
    func pause()
}

/// A simple service to orchestrate between all the possibly existing media player objects in the app
public final class MediaPlayerOrchestrator: Pausable {
    private weak var lastUsedPlayer: SingleTrackPlayer?

    public init() {}

    public func newPlaybackStarted(playable: Pausable) {
        defer {
            if let playable = playable as? SingleTrackPlayer {
                lastUsedPlayer = playable
            }
        }

        guard let lastUsedPlayer,
              !(lastUsedPlayer === playable as? SingleTrackPlayer),
              lastUsedPlayer.playerState == .playing else {
            return
        }

        lastUsedPlayer.pause()
    }

    public func pause() {
        lastUsedPlayer?.pause()
    }
}
