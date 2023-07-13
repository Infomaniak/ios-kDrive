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

import Foundation
import MediaPlayer

enum NowPlayableCommand: CaseIterable {
    case pause, play, stop, togglePausePlay
    case nextTrack, previousTrack, changeRepeatMode, changeShuffleMode
    case changePlaybackRate, seekBackward, seekForward, skipBackward, skipForward, changePlaybackPosition
    case rating, like, dislike
    case bookmark
    case enableLanguageOption, disableLanguageOption

    /// The underlying `MPRemoteCommandCenter` command for this `NowPlayable` command.
    var remoteCommand: MPRemoteCommand {
        let remoteCommandCenter = MPRemoteCommandCenter.shared()

        switch self {
        case .pause:
            return remoteCommandCenter.pauseCommand
        case .play:
            return remoteCommandCenter.playCommand
        case .stop:
            return remoteCommandCenter.stopCommand
        case .togglePausePlay:
            return remoteCommandCenter.togglePlayPauseCommand
        case .nextTrack:
            return remoteCommandCenter.nextTrackCommand
        case .previousTrack:
            return remoteCommandCenter.previousTrackCommand
        case .changeRepeatMode:
            return remoteCommandCenter.changeRepeatModeCommand
        case .changeShuffleMode:
            return remoteCommandCenter.changeShuffleModeCommand
        case .changePlaybackRate:
            return remoteCommandCenter.changePlaybackRateCommand
        case .seekBackward:
            return remoteCommandCenter.seekBackwardCommand
        case .seekForward:
            return remoteCommandCenter.seekForwardCommand
        case .skipBackward:
            return remoteCommandCenter.skipBackwardCommand
        case .skipForward:
            return remoteCommandCenter.skipForwardCommand
        case .changePlaybackPosition:
            return remoteCommandCenter.changePlaybackPositionCommand
        case .rating:
            return remoteCommandCenter.ratingCommand
        case .like:
            return remoteCommandCenter.likeCommand
        case .dislike:
            return remoteCommandCenter.dislikeCommand
        case .bookmark:
            return remoteCommandCenter.bookmarkCommand
        case .enableLanguageOption:
            return remoteCommandCenter.enableLanguageOptionCommand
        case .disableLanguageOption:
            return remoteCommandCenter.disableLanguageOptionCommand
        }
    }

    /// Remove all handlers associated with this command.
    func removeHandler() {
        remoteCommand.removeTarget(nil)
    }

    /// Install a handler for this command.
    func addHandler(_ handler: @escaping (NowPlayableCommand, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) {
        switch self {
        case .changePlaybackRate:
            MPRemoteCommandCenter.shared().changePlaybackRateCommand.supportedPlaybackRates = [1.0, 2.0]
        case .skipBackward:
            MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [15.0]
        case .skipForward:
            MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [15.0]
        default:
            break
        }

        remoteCommand.addTarget { handler(self, $0) }
    }

    /// Disable this command.
    func setDisabled(_ isDisabled: Bool) {
        remoteCommand.isEnabled = !isDisabled
    }
}
